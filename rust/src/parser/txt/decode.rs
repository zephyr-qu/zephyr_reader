//! TXT 文件编码检测与解码
//! 支持 UTF-8, GBK, GB2312, Big5 等常见中文编码

use crate::ffi::ParserError;
use chardetng::EncodingDetector;
use encoding_rs::{Encoding, GB18030, UTF_16BE, UTF_16LE, UTF_8};
use memmap2::Mmap;
use std::fs::File;

/// BOM 标记字节
const UTF8_BOM: [u8; 3] = [0xEF, 0xBB, 0xBF];
const UTF16_LE_BOM: [u8; 2] = [0xFF, 0xFE];
const UTF16_BE_BOM: [u8; 2] = [0xFE, 0xFF];

/// 检测文件编码（使用内存映射，高性能）
pub fn detect_encoding(file_path: &str) -> Result<&'static Encoding, ParserError> {
    let file = File::open(file_path)
        .map_err(|_e| ParserError::file_not_found(format!("无法打开文件：{}", file_path)))?;

    // 使用内存映射读取文件，避免一次性加载到内存
    let mmap = unsafe {
        Mmap::map(&file).map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?
    };

    if mmap.is_empty() {
        return Ok(UTF_8);
    }

    // 仅使用前 4096 字节进行检测，提高性能
    let len = mmap.len().min(4096);
    detect_encoding_from_bytes(&mmap[..len])
}

/// 从字节数组检测编码
pub fn detect_encoding_from_bytes(buffer: &[u8]) -> Result<&'static Encoding, ParserError> {
    // 检查 BOM
    if buffer.starts_with(&UTF8_BOM) {
        return Ok(UTF_8);
    }
    if buffer.starts_with(&UTF16_LE_BOM) {
        return Ok(UTF_16LE);
    }
    if buffer.starts_with(&UTF16_BE_BOM) {
        return Ok(UTF_16BE);
    }

    // 使用 chardetng 检测编码
    let mut detector = EncodingDetector::new();
    detector.feed(buffer, buffer.len() < 1024);

    // 信任 chardetng 的检测结果
    let detected = detector.guess(None, true);

    // 如果检测为 UTF-8，验证其有效性
    if detected == UTF_8 {
        // 尝试将缓冲区作为 UTF-8 解码，检查是否有效
        if std::str::from_utf8(buffer).is_ok() {
            return Ok(UTF_8);
        }
        // 如果 UTF-8 无效，回退到 GB18030
        log::warn!("检测到 UTF-8 但解码失败，尝试使用 GB18030");
        return Ok(GB18030);
    }

    // 对于 GBK 检测结果，使用 GB18030（兼容 GBK/GB2312）
    if detected.name() == "GBK" || detected.name() == "GB2312" {
        return Ok(GB18030);
    }

    Ok(detected)
}

/// 解码文件内容（使用内存映射优化，高性能）
pub fn decode_file(file_path: &str) -> Result<String, ParserError> {
    let file = File::open(file_path)
        .map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?;

    let mmap = unsafe {
        Mmap::map(&file).map_err(|e| ParserError::file_read_error(file_path, e.to_string()))?
    };

    if mmap.is_empty() {
        return Ok(String::new());
    }

    // 检测编码
    let encoding = detect_encoding_from_bytes(&mmap[..mmap.len().min(4096)])?;

    // 如果是 UTF-8 且没有错误，可以直接尝试转换为 String
    if encoding == UTF_8 {
        if let Ok(content) = std::str::from_utf8(&mmap) {
            return Ok(content.to_string());
        }
    }

    // 解码
    let (content, _, had_errors) = encoding.decode(&mmap);

    if had_errors {
        log::warn!("解码文件时遇到错误，部分字符可能无法正确显示");
    }

    Ok(content.into_owned())
}

/// 从字节数组解码内容
pub fn decode_bytes(bytes: &[u8], encoding: &'static Encoding) -> String {
    let (content, _, had_errors) = encoding.decode(bytes);
    if had_errors {
        log::warn!("解码字节时遇到错误");
    }
    content.into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_utf8_encoding() {
        let temp_dir = std::env::temp_dir();
        let file_path = temp_dir.join("test_utf8.txt");

        std::fs::write(&file_path, "Hello 世界").unwrap();

        let encoding = detect_encoding(file_path.to_str().unwrap()).unwrap();
        assert_eq!(encoding, UTF_8);

        std::fs::remove_file(file_path).ok();
    }

    #[test]
    fn test_detect_encoding_from_bytes() {
        // 使用 ASCII 字节字符串进行测试
        let utf8_bytes = b"Hello World";
        let encoding = detect_encoding_from_bytes(utf8_bytes).unwrap();
        assert_eq!(encoding, UTF_8);
    }
}
