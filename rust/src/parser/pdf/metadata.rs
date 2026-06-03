//! PDF 元数据提取模块
//! 负责从 PDF 文件中提取标题、作者、主题等元数据信息
//!
//! 策略：
//! 1. 通过 pdfium-render 获取页面数
//! 2. 通过解析 PDF 原始字节中的 /Info 字典提取标题/作者等字段
//!    /Info 字典在 trailer 中引用，纯文本可解析

use pdfium_render::prelude::Pdfium;
use crate::domain::{AppError, PdfMetadata};

/// 从文件路径打开 PDF 并提取元数据
pub fn extract_metadata_from_path(file_path: &str) -> Result<PdfMetadata, AppError> {
    let pdfium = Pdfium::default();

    let pdf = pdfium
        .load_pdf_from_file(file_path, None)
        .map_err(|e| {
            AppError::file_read_error(
                file_path.to_string(),
                format!("PDF document open failed: {}", e),
            )
        })?;

    // 尝试从 /Info 字典解析元数据（失败时返回默认值，不阻塞）
    let mut metadata = parse_pdf_info_dict(file_path).unwrap_or_default();
    metadata.page_count = pdf.pages().len();

    tracing::debug!(
        "PDF metadata extraction complete: title={:?}, author={:?}, pages={}",
        metadata.title,
        metadata.author,
        metadata.page_count
    );

    Ok(metadata)
}

// ==================== /Info 字典解析 ====================

/// 从 PDF 原始字节中解析 /Info 字典
///
/// PDF 的 trailer 中包含 `/Info N 0 R` 引用，指向一个包含元数据的字典对象。
/// 该字典的格式为：
/// ```text
/// N 0 obj
/// << /Title (...) /Author (...) /Subject (...) /Creator (...) >>
/// endobj
/// ```
fn parse_pdf_info_dict(file_path: &str) -> Result<PdfMetadata, AppError> {
    let bytes = std::fs::read(file_path)
        .map_err(|e| AppError::file_read_error(file_path.to_string(), e.to_string()))?;

    // 1. 在文件末尾查找 trailer 块
    let trailer = find_trailer(&bytes)
        .ok_or_else(|| AppError::pdf_parse_error("cannot find PDF trailer"))?;

    // 2. 从 trailer 字典中解析 /Info 对象引用号
    let info_ref = parse_info_ref(trailer)?;

    // 3. 定位 /Info 对象字节段
    let obj_bytes = find_object(&bytes, info_ref)
        .ok_or_else(|| AppError::pdf_parse_error(format!("Info object {} not found", info_ref)))?;

    // 4. 提取字段
    Ok(PdfMetadata {
        title: extract_pdf_string(obj_bytes, b"/Title"),
        author: extract_pdf_string(obj_bytes, b"/Author"),
        subject: extract_pdf_string(obj_bytes, b"/Subject"),
        creator: extract_pdf_string(obj_bytes, b"/Creator"),
        page_count: 0, // 由调用者填充
    })
}

/// 在 PDF 字节末尾（最后 4096 字节内）查找 `trailer<<` 块
fn find_trailer(bytes: &[u8]) -> Option<&[u8]> {
    let search_start = bytes.len().saturating_sub(4096);
    let tail = &bytes[search_start..];

    // 在末尾搜索 "trailer" 关键字
    let trailer_start = tail
        .windows(7)
        .rposition(|w| w.eq_ignore_ascii_case(b"trailer"))?;

    let after_trailer = &tail[trailer_start + 7..];

    // 找到字典开始 <<
    let dict_start = after_trailer.iter().position(|&b| b == b'<')?;
    Some(&after_trailer[dict_start..])
}

/// 从 trailer 字典中解析 `/Info N 0 R` 返回对象号 N
fn parse_info_ref(trailer: &[u8]) -> Result<u32, AppError> {
    // 在 trailer 字典中查找 /Info
    let info_pos = trailer
        .windows(6)
        .position(|w| w.eq_ignore_ascii_case(b"/Info "))
        .or_else(|| {
            trailer
                .windows(6)
                .position(|w| w.eq_ignore_ascii_case(b"/Info\r"))
        })
        .or_else(|| {
            trailer
                .windows(6)
                .position(|w| w.eq_ignore_ascii_case(b"/Info\n"))
        })
        .ok_or_else(|| AppError::pdf_parse_error("/Info not found in trailer"))?;

    let after_info = &trailer[info_pos + 5..]; // skip "/Info"

    // 解析 "N 0 R" 格式的对象引用
    // 跳过可能出现的空格和换行
    let after_trimmed = after_info.trim_ascii_start();

    let mut parts = after_trimmed.splitn(3, |b: &u8| b.is_ascii_whitespace());
    let num_str = parts.next().ok_or_else(|| {
        AppError::pdf_parse_error("cannot parse Info object number")
    })?;

    let num = std::str::from_utf8(num_str)
        .map_err(|_| AppError::pdf_parse_error("Info object number is not valid UTF-8"))?;

    num.parse::<u32>()
        .map_err(|e| AppError::pdf_parse_error(format!("invalid Info object number: {}", e)))
}

/// 在 PDF 字节中查找对象 `N 0 obj ... endobj` 并返回内容段
fn find_object(bytes: &[u8], obj_num: u32) -> Option<&[u8]> {
    let marker = format!("{} 0 obj", obj_num);
    let marker_bytes = marker.as_bytes();

    // 搜索 "N 0 obj" 标记
    let obj_start = bytes
        .windows(marker_bytes.len())
        .position(|w| w == marker_bytes)?;

    let after_marker = &bytes[obj_start + marker_bytes.len()..];

    // 查找 endobj
    let end_pos = after_marker
        .windows(6)
        .position(|w| w == b"endobj")?;

    Some(&after_marker[..end_pos])
}

/// 从字典字节段中提取指定键对应的括号字符串值
///
/// PDF 字符串格式：`(text)`，支持转义括号 `\(` 和 `\)`
fn extract_pdf_string(dict_bytes: &[u8], key: &[u8]) -> Option<String> {
    // 查找 /Key 后跟空格或换行
    let key_pos = dict_bytes
        .windows(key.len())
        .position(|w| w == key)?;

    let after_key = &dict_bytes[key_pos + key.len()..];
    let after_key = after_key.trim_ascii_start();

    // 找到第一个左括号
    let paren_start = after_key.iter().position(|&b| b == b'(')?;
    let after_open = &after_key[paren_start + 1..];

    // 提取括号内内容，处理转义
    let mut result = Vec::new();
    let mut depth = 1u32;
    let mut i = 0;

    while i < after_open.len() && depth > 0 {
        match after_open[i] {
            b'(' => {
                depth += 1;
                result.push(b'(');
                i += 1;
            }
            b')' => {
                depth -= 1;
                if depth > 0 {
                    result.push(b')');
                }
                i += 1;
            }
            b'\\' if i + 1 < after_open.len() => {
                // 转义序列
                match after_open[i + 1] {
                    b'n' => result.push(b'\n'),
                    b'r' => result.push(b'\r'),
                    b't' => result.push(b'\t'),
                    b'(' | b')' | b'\\' => result.push(after_open[i + 1]),
                    _ => {
                        result.push(b'\\');
                        result.push(after_open[i + 1]);
                    }
                }
                i += 2;
            }
            b => {
                result.push(b);
                i += 1;
            }
        }
    }

    if result.is_empty() {
        return None;
    }

    // 编码检测：UTF-16BE BOM 处理
    if result.len() >= 2 && result[0] == 0xFE && result[1] == 0xFF {
        // UTF-16BE 编码
        let utf16_chars: Vec<u16> = result[2..]
            .chunks_exact(2)
            .map(|c| u16::from_be_bytes([c[0], c[1]]))
            .collect();
        String::from_utf16(&utf16_chars).ok()
    } else {
        // 默认当作 PDFDocEncoding（近似 Latin-1，字节 0x80-0x9F 有特殊映射）
        // 对于 ASCII 范围，直接使用 String::from_utf8
        // 对于 0x80+，使用 Latin-1 近似（字节 -> Unicode 码点直接映射）
        let s = String::from_utf8(result.clone()).unwrap_or_else(|_| {
            result
                .iter()
                .map(|&b| b as char)
                .collect::<String>()
        });
        if s.is_empty() { None } else { Some(s) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
    fn test_extract_metadata_file_not_found() {
        let result = extract_metadata_from_path("non_existent.pdf");
        assert!(result.is_err());
    }

    #[test]
    fn test_find_trailer_trivial() {
        let pdf = b"%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Size 1/Root 1 0 R/Info 2 0 R>>\nstartxref\n42\n%%EOF";
        let trailer = find_trailer(pdf).unwrap();
        let trailer_str = std::str::from_utf8(trailer).unwrap();
        assert!(trailer_str.contains("/Info 2 0 R"));
    }

    #[test]
    fn test_parse_info_ref() {
        let trailer = b"<< /Size 1 /Root 1 0 R /Info 42 0 R >>";
        let info_ref = parse_info_ref(trailer).unwrap();
        assert_eq!(info_ref, 42);
    }

    #[test]
    fn test_parse_info_ref_no_info() {
        let trailer = b"<< /Size 1 /Root 1 0 R >>";
        let result = parse_info_ref(trailer);
        assert!(result.is_err());
    }

    #[test]
    fn test_find_object() {
        let pdf = b"some garbage\n42 0 obj\n<< /Title (Hello) >>\nendobj\nmore garbage";
        let obj = find_object(pdf, 42).unwrap();
        let obj_str = std::str::from_utf8(obj).unwrap().trim();
        assert!(obj_str.contains("/Title"));
    }

    #[test]
    fn test_find_object_not_found() {
        let pdf = b"some garbage\n42 0 obj\n<< /Title (Hello) >>\nendobj\n";
        assert!(find_object(pdf, 99).is_none());
    }

    #[test]
    fn test_extract_pdf_string() {
        let dict = b"<< /Title (Hello World) /Author (John Doe) >>";
        assert_eq!(
            extract_pdf_string(dict, b"/Title").as_deref(),
            Some("Hello World")
        );
        assert_eq!(
            extract_pdf_string(dict, b"/Author").as_deref(),
            Some("John Doe")
        );
        assert_eq!(extract_pdf_string(dict, b"/Subject"), None);
    }

    #[test]
    fn test_extract_pdf_string_escaped_parens() {
        let dict = b"<< /Title (Hello \\(World\\)) >>";
        assert_eq!(
            extract_pdf_string(dict, b"/Title").as_deref(),
            Some("Hello (World)")
        );
    }

    #[test]
    fn test_extract_pdf_string_empty() {
        let dict = b"<< /Title () >>";
        assert_eq!(extract_pdf_string(dict, b"/Title"), None);
    }

    #[test]
    fn test_parse_pdf_info_dict_invalid_path() {
        let result = parse_pdf_info_dict("/nonexistent/file.pdf");
        assert!(result.is_err());
    }
}
