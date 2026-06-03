//! TXT 文件编码检测与解码
//! 支持 UTF-8, GBK, GB2312, Big5 等常见中文编码

use crate::domain::AppError;
use chardetng::{EncodingDetector, Iso2022JpDetection, Utf8Detection};
use encoding_rs::{Encoding, GB18030, UTF_8, UTF_16BE, UTF_16LE};
use memmap2::Mmap;
use std::fs::File;

/// BOM 标记字节
const UTF8_BOM: [u8; 3] = [0xEF, 0xBB, 0xBF];
const UTF16_LE_BOM: [u8; 2] = [0xFF, 0xFE];
const UTF16_BE_BOM: [u8; 2] = [0xFE, 0xFF];

/// 从字节数组检测编码
pub fn detect_encoding_from_bytes(buffer: &[u8]) -> Result<&'static Encoding, AppError> {
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
    let mut detector = EncodingDetector::new(Iso2022JpDetection::Deny);
    detector.feed(buffer, buffer.len() < 1024);

    let detected = detector.guess(None, Utf8Detection::Allow);

    // 如果检测为 UTF-8，验证其有效性
    if detected == UTF_8 {
        // 尝试将缓冲区作为 UTF-8 解码，检查是否有效
        if std::str::from_utf8(buffer).is_ok() {
            return Ok(UTF_8);
        }
        // 如果 UTF-8 无效，回退到 GB18030
        tracing::warn!("UTF-8 detected but decode failed, falling back to GB18030");
        return Ok(GB18030);
    }

    // 对于 GBK 检测结果，使用 GB18030（兼容 GBK/GB2312）
    if detected.name() == "GBK" || detected.name() == "GB2312" {
        return Ok(GB18030);
    }

    Ok(detected)
}

/// 解码文件内容（使用内存映射优化，高性能）
pub fn decode_file(file_path: &str) -> Result<String, AppError> {
    let file =
        File::open(file_path).map_err(|e| AppError::file_read_error(file_path, e.to_string()))?;

    // SAFETY: 文件以只读方式打开（File::open），映射为只读 Mmap；
    // 文件在映射生命周期内不会被写入或截断（调用方保证）。
    // memmap2 在 Drop 时自动解除映射。
    let mmap = unsafe {
        Mmap::map(&file).map_err(|e| AppError::file_read_error(file_path, e.to_string()))?
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
        tracing::warn!("decoding errors encountered, some characters may not display correctly");
    }

    Ok(content.into_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_encoding_from_bytes() {
        // 使用 ASCII 字节字符串进行测试
        let utf8_bytes = b"Hello World";
        let encoding = detect_encoding_from_bytes(utf8_bytes).unwrap();
        assert_eq!(encoding, UTF_8);
    }
}
