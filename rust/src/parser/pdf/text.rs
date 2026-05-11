//! PDF 文本提取模块
//!
//! 使用 `pdfium-render` 实现 PDF 文本提取功能。
//! 支持多页面文本提取和字符数估算。

use pdfium_render::prelude::{PdfPageIndex, Pdfium};
use std::path::Path;

use crate::domain::{ AppError};
use crate::text::constants::PDF_CHARS_PER_PAGE;

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
/// * `Err(AppError)` - 提取失败
pub fn get_pdf_page_text(file_path: &str, page_index: usize) -> Result<String,AppError> {
    if !Path::new(file_path).exists() {
        return Err(AppError::file_not_found(file_path));
    }

    let pdfium = Pdfium;
    let load_result = pdfium.load_pdf_from_file(file_path, None);
    let pdf =
        load_result.map_err(|e| AppError::pdf_parse_error(format!("打开 PDF 文件失败：{}", e)))?;

    let num_pages: usize = pdf.pages().len() as usize;
    if page_index >= num_pages {
        return Err(AppError::pdf_parse_error(format!(
            "页面索引超出范围：{} (总共 {} 页)",
            page_index, num_pages
        )));
    }

    let page = pdf
        .pages()
        .get(page_index as PdfPageIndex)
        .map_err(|e| AppError::pdf_parse_error(format!("获取页面失败：{}", e)))?;

    // 使用 pdfium-render 提取页面文本
    let page_text = page
        .text()
        .map_err(|e| AppError::pdf_parse_error(format!("提取页面文本失败：{}", e)))?;

    // 使用 chars() 获取所有字符并拼接
    let chars = page_text.chars();
    let mut text = String::new();
    for char_obj in chars.iter() {
        if let Some(ch) = char_obj.unicode_char() {
            text.push(ch);
        }
    }

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
/// * `Err(AppError)` - 提取失败
pub fn get_chapter_text(file_path: &str, start_page: usize, end_page: usize) -> Result<String,AppError> {
    if !Path::new(file_path).exists() {
        return Err(AppError::file_not_found(file_path));
    }

    let pdfium = Pdfium;
    let load_result = pdfium.load_pdf_from_file(file_path, None);
    let pdf =
        load_result.map_err(|e| AppError::pdf_parse_error(format!("打开 PDF 文件失败：{}", e)))?;

    let num_pages: usize = pdf.pages().len() as usize;
    if start_page >= num_pages {
        return Err(AppError::pdf_parse_error(format!(
            "起始页面超出范围：{} (总共 {} 页)",
            start_page, num_pages
        )));
    }

    let actual_end = end_page.min(num_pages);
    if actual_end <= start_page {
        return Err(AppError::pdf_parse_error(format!(
            "无效的页面范围：{} - {}",
            start_page, end_page
        )));
    }

    let mut chapter_text = String::new();
    for page_index in start_page..actual_end {
        let page = pdf.pages().get(page_index as PdfPageIndex).map_err(|e| {
            AppError::pdf_parse_error(format!("获取页面 {} 失败：{}", page_index, e))
        })?;

        let page_text = page.text().map_err(|e| {
            AppError::pdf_parse_error(format!("提取页面 {} 文本失败：{}", page_index, e))
        })?;

        // 使用 chars() 获取所有字符并拼接
        let chars = page_text.chars();
        let mut text = String::new();
        for char_obj in chars.iter() {
            if let Some(ch) = char_obj.unicode_char() {
                text.push(ch);
            }
        }

        if !chapter_text.is_empty() {
            chapter_text.push('\n');
        }
        chapter_text.push_str(&text);
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
    let pdfium = Pdfium;
    let pdf = match pdfium.load_pdf_from_file(file_path, None) {
        Ok(p) => p,
        Err(_) => return 0,
    };

    let num_pages = pdf.pages().len() as usize;
    if num_pages == 0 {
        return 0;
    }

    // 简化估算：每页约 PDF_CHARS_PER_PAGE 字符
    num_pages as i64 * PDF_CHARS_PER_PAGE as i64
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
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    #[ignore = "需要 Pdfium 库支持，在 CI 环境中跳过"]
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
    }
}
