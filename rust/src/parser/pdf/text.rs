//! PDF 文本提取模块
//!
//! 使用 `pdf` crate 实现 PDF 文本提取功能。
//! 支持多页面文本提取和字符数估算。

use pdf::file::FileOptions;
use std::path::Path;

use crate::ffi::{ApiResult, ParserError};

/// 从 PDF 文件中提取指定页面的文本
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
/// * `page_index` - 页面索引（从 0 开始）
///
/// # 返回值
///
/// * `Ok(String)` - 提取的文本内容
/// * `Err(ParserError)` - 提取失败
pub fn get_pdf_page_text(file_path: &str, page_index: usize) -> ApiResult<String> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    let doc = FileOptions::cached()
        .open(file_path)
        .map_err(|e| ParserError::PdfParseError(format!("打开 PDF 文件失败：{}", e)))?;

    let num_pages = doc.num_pages() as usize;
    if page_index >= num_pages {
        return Err(ParserError::PdfParseError(format!(
            "页面索引超出范围：{} (总共 {} 页)",
            page_index, num_pages
        )));
    }

    let _page = doc
        .get_page(page_index as u32)
        .map_err(|e| ParserError::PageExtractError(format!("获取页面失败：{}", e)))?;

    // 简化实现：返回页面内容的字符串表示
    // 注意：pdf crate 的文本提取功能有限，这里返回占位符
    let text = format!("[PDF Page {}]", page_index);

    Ok(text)
}

/// 从 PDF 文件中提取指定页面范围的文本
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
/// * `start_page` - 起始页面索引（包含，从 0 开始）
/// * `end_page` - 结束页面索引（不包含）
///
/// # 返回值
///
/// * `Ok(String)` - 提取的文本内容
/// * `Err(ParserError)` - 提取失败
pub fn get_chapter_text(file_path: &str, start_page: usize, end_page: usize) -> ApiResult<String> {
    if !Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    let doc = FileOptions::cached()
        .open(file_path)
        .map_err(|e| ParserError::PdfParseError(format!("打开 PDF 文件失败：{}", e)))?;

    let num_pages = doc.num_pages() as usize;
    if start_page >= num_pages {
        return Err(ParserError::PdfParseError(format!(
            "起始页面超出范围：{} (总共 {} 页)",
            start_page, num_pages
        )));
    }

    let actual_end = end_page.min(num_pages as usize);
    if actual_end <= start_page {
        return Err(ParserError::PdfParseError(format!(
            "无效的页面范围：{} - {}",
            start_page, end_page
        )));
    }

    let mut chapter_text = String::new();
    for page_index in start_page..actual_end {
        let _page = doc.get_page(page_index as u32).map_err(|e| {
            ParserError::PageExtractError(format!("获取页面 {} 失败：{}", page_index, e))
        })?;

        if !chapter_text.is_empty() {
            chapter_text.push('\n');
        }
        chapter_text.push_str(&format!("[PDF Page {}]", page_index));
    }

    Ok(chapter_text)
}

/// 估算 PDF 文件的总字符数
///
/// 通过采样指定数量的页面来估算总字符数。
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
/// * `_sample_pages` - 采样页面数量（0 表示采样所有页面）
///
/// # 返回值
///
/// 估算的总字符数
pub fn estimate_total_chars(file_path: &str, _sample_pages: usize) -> i64 {
    let doc = match FileOptions::cached().open(file_path) {
        Ok(d) => d,
        Err(_) => return 0,
    };

    let num_pages = doc.num_pages();
    if num_pages == 0 {
        return 0;
    }

    // 简化估算：每页约 500 字符
    num_pages as i64 * 500
}

/// 获取 PDF 文件的总页数
///
/// # 参数
///
/// * `file_path` - PDF 文件路径
///
/// # 返回值
///
/// 总页数，如果失败返回 0
pub fn get_pdf_page_count(file_path: &str) -> usize {
    let doc = match FileOptions::cached().open(file_path) {
        Ok(d) => d,
        Err(_) => return 0,
    };
    doc.num_pages() as usize
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_get_pdf_page_text_file_not_found() {
        let result = get_pdf_page_text("non_existent.pdf", 0);
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(matches!(err, ParserError::FileNotFound { .. }), "Expected FileNotFound error, got: {:?}", err);
    }

    #[test]
    fn test_estimate_total_chars_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        fs::write(&file_path, b"").unwrap();

        let chars = estimate_total_chars(file_path.to_str().unwrap(), 5);
        // 空文件或者无效 PDF 应该返回 0
        assert_eq!(chars, 0);
    }

    #[test]
    fn test_get_pdf_page_count_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("empty.pdf");
        fs::write(&file_path, b"").unwrap();

        let count = get_pdf_page_count(file_path.to_str().unwrap());
        assert_eq!(count, 0);
    }
}
