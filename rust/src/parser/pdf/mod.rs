//! PDF 解析模块
//! 负责 PDF 文件的解压、结构解析、文本提取

pub mod images;
pub mod metadata;
pub mod parse;
pub mod text;

use std::path::Path;
use std::sync::Arc;

use flutter_rust_bridge::frb;

use crate::domain::{ ParseResult, AppError};
use crate::domain::parser::{BookMetadata, BookParser};

pub use images::extract_pdf_cover;
pub use parse::async_parse_pdf_file;
pub use parse::get_pdf_metadata;
pub use parse::parse_pdf;
pub use text::get_chapter_text;
pub use text::get_pdf_page_text;

/// PDF 文件解析器
#[frb(opaque)]
pub struct PdfParser;

impl PdfParser {
    pub fn new() -> Self {
        Self
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

    fn parse(&self, file_path: &str) -> Result<ParseResult,AppError> {
        parse_pdf(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata,AppError> {
        if !Path::new(file_path).exists() {
            return Err(AppError::file_not_found(file_path));
        }

        let metadata = get_pdf_metadata(file_path.to_string());

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
            total_characters: 0,
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_index: i32) -> Result<String,AppError> {
        let pages_per_chapter = 10;
        let start_page = (chapter_index as usize * pages_per_chapter) as u32;
        let end_page = ((chapter_index as usize + 1) * pages_per_chapter) as u32;

        get_chapter_text(file_path, start_page as usize, end_page as usize)
    }
}

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
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
