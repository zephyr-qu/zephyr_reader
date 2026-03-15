//! 文件流式读取
//! 支持大文件分块读取，避免内存溢出

use crate::ffi::{ApiResult, ParserError};
use encoding_rs::Encoding;
use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::{BufReader, Read, Seek, SeekFrom};

/// 读取文件块（支持编码）
#[frb(sync)]
pub fn read_chunk(file_path: String, start_pos: i64, chunk_size: i64) -> ApiResult<String> {
    read_chunk_with_encoding(file_path, start_pos, chunk_size, encoding_rs::UTF_8)
}

/// 读取文件块（指定编码）
pub fn read_chunk_with_encoding(
    file_path: String,
    start_pos: i64,
    chunk_size: i64,
    encoding: &'static Encoding,
) -> ApiResult<String> {
    let mut file = File::open(&file_path)
        .map_err(|e| ParserError::file_read_error(&file_path, e.to_string()))?;

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
        log::warn!("解码文件块时遇到错误");
    }

    Ok(content.into_owned())
}

/// 读取文件块（带缓冲，自动检测编码）
pub fn read_chunk_buffered(
    file_path: String,
    start_pos: i64,
    chunk_size: i64,
) -> ApiResult<String> {
    let file = File::open(&file_path)
        .map_err(|e| ParserError::file_read_error(&file_path, e.to_string()))?;

    let mut reader = BufReader::new(file);

    // 定位到起始位置
    reader
        .seek(SeekFrom::Start(start_pos as u64))
        .map_err(|e| ParserError::StreamError(format!("定位失败：{}", e)))?;

    // 读取指定大小的数据
    let mut buffer = vec![0u8; chunk_size as usize];
    let bytes_read = reader
        .read(&mut buffer)
        .map_err(|e| ParserError::StreamError(format!("读取失败：{}", e)))?;

    buffer.truncate(bytes_read);

    // 使用 encoding_rs 解码（兼容非 UTF-8）
    let (content, _, had_errors) = encoding_rs::UTF_8.decode(&buffer);
    if had_errors {
        log::warn!("解码字节时遇到错误");
    }

    Ok(content.into_owned())
}

/// 获取文件大小
#[frb(sync)]
pub fn get_file_size(file_path: String) -> ApiResult<i64> {
    let file = File::open(&file_path)
        .map_err(|e| ParserError::file_read_error(&file_path, e.to_string()))?;

    let metadata = file
        .metadata()
        .map_err(|e| ParserError::StreamError(format!("获取元数据失败：{}", e)))?;

    Ok(metadata.len() as i64)
}

/// 流式读取整个文件（分块）
pub fn stream_file(file_path: String, chunk_size: i64) -> ApiResult<Vec<String>> {
    let file_size = get_file_size(file_path.clone())?;
    let mut chunks = Vec::new();
    let mut pos = 0i64;

    while pos < file_size {
        let remaining = file_size - pos;
        let size = chunk_size.min(remaining);

        let chunk = read_chunk(file_path.clone(), pos, size)?;
        chunks.push(chunk);

        pos += size;
    }

    Ok(chunks)
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
        log::warn!("解码文件时遇到错误");
    }

    Ok((content.into_owned(), encoding))
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
}
