//! PDF 文件解析器实现
//!
//! 实现 `BookParser` trait，提供 PDF 文件格式的解析支持。

use std::path::Path;
use std::sync::Arc;

use crate::ffi::{ApiResult, ParseResult, ParserError};
use crate::parser::traits::{BookMetadata, BookParser};

/// PDF 文件解析器
pub struct PdfParser {}

impl PdfParser {
    /// 创建新的 PDF 解析器实例
    pub fn new() -> Self {
        Self {}
    }
}

impl Default for PdfParser {
    fn default() -> Self {
        Self::new()
    }
}

impl BookParser for PdfParser {
    fn name(&self) -> &str {
        "PDF Parser"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["pdf"]
    }

    fn parse(&self, file_path: &str) -> ApiResult<ParseResult> {
        crate::parser::parse_pdf(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> ApiResult<BookMetadata> {
        use crate::parser::pdf::parse::get_pdf_metadata;

        if !Path::new(file_path).exists() {
            return Err(ParserError::file_not_found(file_path));
        }

        let metadata = get_pdf_metadata(file_path.to_string());

        // 从文件名提取书名
        let title = metadata.title.clone().unwrap_or_else(|| {
            Path::new(file_path)
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("未知书籍")
                .to_string()
        });

        Ok(BookMetadata {
            title,
            author: metadata.author.unwrap_or_else(|| "未知作者".to_string()),
            description: None,
            cover_path: None,
            publish_year: None,
            language: None,
            chapter_count: metadata.page_count,
            total_characters: 0, // PDF 字符数需要额外计算
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_id: i32) -> ApiResult<String> {
        use crate::parser::pdf::text::get_chapter_text;

        // PDF 每 10 页为一章
        let pages_per_chapter = 10;
        let start_page = (chapter_id as usize * pages_per_chapter) as u32;
        let end_page = ((chapter_id as usize + 1) * pages_per_chapter) as u32;

        get_chapter_text(file_path, start_page as usize, end_page as usize)
    }
}

/// 创建 PDF 解析器实例（方便外部使用）
pub fn create_pdf_parser() -> Arc<dyn BookParser> {
    Arc::new(PdfParser::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pdf_parser_name() {
        let parser = PdfParser::new();
        assert_eq!(parser.name(), "PDF Parser");
    }

    #[test]
    fn test_pdf_parser_supported_formats() {
        let parser = PdfParser::new();
        let formats = parser.supported_formats();
        assert!(formats.contains(&"pdf"));
    }

    #[test]
    fn test_pdf_parser_supports_format() {
        let parser = PdfParser::new();
        assert!(parser.supports_format("pdf"));
        assert!(parser.supports_format("PDF"));
        assert!(!parser.supports_format("txt"));
    }

    #[test]
    fn test_pdf_parser_parse_file_not_found() {
        let parser = PdfParser::new();
        let result = parser.parse("non_existent.pdf");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
