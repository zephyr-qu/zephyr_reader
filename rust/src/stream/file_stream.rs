//! 文件流式读取
//! 支持大文件分块读取，避免内存溢出
//!
//! 使用 `memmap2` 库实现内存映射文件读取，
//! 对于大文件（>1MB）可显著提升性能。

use crate::ffi::{ApiResult, ParserError};
use encoding_rs::Encoding;
use flutter_rust_bridge::frb;
use memmap2::Mmap;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};

/// 文件大小阈值（1MB），超过此值使用内存映射
const MMAP_THRESHOLD: i64 = 1024 * 1024;

/// 读取文件块（支持编码）
///
/// 自动选择最优读取方式：
/// - 文件 > 1MB：使用内存映射（memmap2）
/// - 文件 ≤ 1MB：使用标准 IO
///
/// # 参数
/// * `file_path` - 文件路径
/// * `start_pos` - 起始位置（字节偏移）
/// * `chunk_size` - 读取大小（字节）
///
/// # 返回值
/// * `Ok(String)` - 文件块内容
/// * `Err(ParserError)` - 读取失败
#[frb(sync)]
pub fn read_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String> {
    read_chunk_with_encoding(file_path, start_pos, chunk_size, encoding_rs::UTF_8)
}

/// 读取文件块（指定编码，内存映射优化版）
///
/// # 参数
/// * `file_path` - 文件路径
/// * `start_pos` - 起始位置（字节偏移）
/// * `chunk_size` - 读取大小（字节）
/// * `encoding` - 字符编码
///
/// # 返回值
/// * `Ok(String)` - 文件块内容
/// * `Err(ParserError)` - 读取失败
pub fn read_chunk_with_encoding(
    file_path: String,
    start_pos: i64,
    chunk_size: i64,
    encoding: &'static Encoding,
) -> ApiResult<String> {
    // 获取文件大小
    let file_size = get_file_size_internal(&file_path)?;

    // 根据文件大小选择读取方式
    if file_size > MMAP_THRESHOLD {
        // 大文件：使用内存映射
        read_chunk_mmap(&file_path, start_pos, chunk_size, encoding)
    } else {
        // 小文件：使用标准 IO（带缓存）
        read_chunk_io_cached(&file_path, start_pos, chunk_size, encoding)
    }
}

/// 使用内存映射读取文件块
fn read_chunk_mmap(
    file_path: &str,
    start_pos: i64,
    chunk_size: i64,
    encoding: &'static Encoding,
) -> ApiResult<String> {
    let file = File::open(file_path)
        .map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?;

    // 创建内存映射
    let mmap = unsafe { Mmap::map(&file) }
        .map_err(|e| ParserError::StreamError(format!("内存映射失败：{}", e)))?;

    // 边界检查
    let mut start = start_pos as usize;
    let mut end = (start + chunk_size as usize).min(mmap.len());

    if start >= mmap.len() {
        return Ok(String::new());
    }

    // UTF-8 边界调整：确保不会从多字节字符中间开始读取
    if encoding == encoding_rs::UTF_8 {
        // 起始边界：如果从续字节开始，回退到起始字节
        // UTF-8 续字节: 10xxxxxx (0x80..=0xBF)
        while start > 0 && start < end && (mmap[start] & 0xC0) == 0x80 {
            start -= 1;
        }

        // 结束边界：如果停在续字节，继续回退
        while end > start && (mmap[end - 1] & 0xC0) == 0x80 {
            end -= 1;
        }
    }

    // 从映射内存中读取
    let buffer = &mmap[start..end];

    // 解码
    let (content, _, had_errors) = encoding.decode(buffer);
    if had_errors {
        tracing::warn!("解码文件块时遇到错误：{}", file_path);
    }

    Ok(content.into_owned())
}

/// 使用标准 IO 读取文件块（带文件句柄缓存）
fn read_chunk_io_cached(
    file_path: &str,
    start_pos: i64,
    chunk_size: i64,
    encoding: &'static Encoding,
) -> ApiResult<String> {
    // 打开文件
    let mut file = File::open(file_path)
        .map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?;

    // 定位到起始位置
    file.seek(SeekFrom::Start(start_pos as u64))
        .map_err(|e| ParserError::StreamError(format!("定位失败：{}", e)))?;

    // 读取指定大小的数据
    let mut buffer = vec![0u8; chunk_size as usize];
    let bytes_read = file
        .read(&mut buffer)
        .map_err(|e| ParserError::StreamError(format!("读取失败：{}", e)))?;

    // 截断实际读取的数据
    buffer.truncate(bytes_read);

    // 使用指定编码解码
    let (content, _, had_errors) = encoding.decode(&buffer);
    if had_errors {
        tracing::warn!("解码文件块时遇到错误：{}", file_path);
    }

    Ok(content.into_owned())
}

/// 获取文件大小（内部版本，避免重复代码）
fn get_file_size_internal(file_path: &str) -> ApiResult<i64> {
    let file = File::open(file_path)
        .map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?;

    let metadata = file
        .metadata()
        .map_err(|e| ParserError::StreamError(format!("获取元数据失败：{}", e)))?;

    Ok(metadata.len() as i64)
}

/// 获取文件大小
#[frb(sync)]
pub fn get_file_size(file_path: String) -> ApiResult<i64> {
    get_file_size_internal(&file_path)
}

/// 检测文件开头编码并读取第一块
pub fn read_first_chunk_with_detect(
    file_path: String,
    chunk_size: i64,
) -> ApiResult<(String, &'static Encoding)> {
    let mut file = File::open(&file_path)
        .map_err(|e| ParserError::file_read_error(&file_path, e.to_string()))?;

    // 读取前 1024 字节用于检测
    let mut detect_buffer = [0u8; 1024];
    let bytes_read = file
        .read(&mut detect_buffer)
        .map_err(|e| ParserError::StreamError(format!("读取失败：{}", e)))?;

    // 检测编码
    let encoding =
        crate::parser::txt::decode::detect_encoding_from_bytes(&detect_buffer[..bytes_read])?;

    // 重新定位到文件开头
    file.seek(SeekFrom::Start(0))
        .map_err(|e| ParserError::StreamError(format!("重新定位失败：{}", e)))?;

    // 读取指定大小的数据
    let mut buffer = vec![0u8; chunk_size as usize];
    let bytes_read = file
        .read(&mut buffer)
        .map_err(|e| ParserError::StreamError(format!("读取失败：{}", e)))?;

    buffer.truncate(bytes_read);

    // 使用检测到的编码解码
    let (content, _, had_errors) = encoding.decode(&buffer);
    if had_errors {
        tracing::warn!("解码文件时遇到错误");
    }

    Ok((content.into_owned(), encoding))
}

/// 清理文件句柄缓存
///
/// 当前实现不使用文件句柄缓存（因为 File 对象无法安全共享），
/// 此函数保留为未来扩展使用。
pub fn clear_file_cache() {
    // 当前无缓存可清理
}

/// 获取文件句柄缓存统计信息
///
/// 当前未使用文件句柄缓存，始终返回 0
pub fn get_cache_stats() -> usize {
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_read_chunk() {
        // 创建临时文件
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_chunk.txt");

        let content = "Hello, World! This is a test file.";
        std::fs::write(&file_path, content).unwrap();

        // 读取前 5 个字符
        let chunk = read_chunk(file_path.to_string_lossy().to_string(), 0, 5).unwrap();
        assert_eq!(chunk, "Hello");

        // 读取接下来的字符
        let chunk = read_chunk(file_path.to_string_lossy().to_string(), 7, 5).unwrap();
        assert_eq!(chunk, "World");

        std::fs::remove_file(file_path).ok();
    }

    #[test]
    fn test_get_file_size() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_size.txt");

        let content = "Hello, World!";
        std::fs::write(&file_path, content).unwrap();

        let size = get_file_size(file_path.to_string_lossy().to_string()).unwrap();
        assert_eq!(size, content.len() as i64);

        std::fs::remove_file(file_path).ok();
    }

    #[test]
    fn test_read_chunk_with_chinese() {
        // 测试中文编码
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_chinese.txt");

        let content = "这是一段中文测试文本";
        std::fs::write(&file_path, content).unwrap();

        // 读取前 9 个字节（3 个中文字符，UTF-8 每个字符 3 字节）
        let chunk = read_chunk_with_encoding(
            file_path.to_string_lossy().to_string(),
            0,
            9,
            encoding_rs::UTF_8,
        )
        .unwrap();
        assert_eq!(chunk, "这是一");

        std::fs::remove_file(file_path).ok();
    }
}
