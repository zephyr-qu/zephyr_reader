//! EPUB 解析模块
//! 负责 EPUB 文件的解压、结构解析、文本提取

pub mod parse;
pub mod toc;
pub mod unzip;

use std::path::Path;
use std::sync::Arc;

use flutter_rust_bridge::frb;

use crate::domain::{ ParseResult, AppError};
use crate::domain::parser::{BookMetadata, BookParser};

pub use parse::parse_epub;

/// EPUB 文件解析器
#[frb(opaque)]
pub struct EpubParser;

impl EpubParser {
    pub fn new() -> Self {
        Self
    }
}

impl Default for EpubParser {
    fn default() -> Self {
        Self::new()
    }
}

impl BookParser for EpubParser {
    fn name(&self) -> &str {
        "EPUB Parser"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["epub"]
    }

    fn parse(&self, file_path: &str) -> Result<ParseResult,AppError> {
        parse_epub(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata,AppError> {
        if !Path::new(file_path).exists() {
            return Err(AppError::file_not_found(file_path));
        }

        let epub_file = unzip::EpubFile::open(file_path)?;

        Ok(BookMetadata {
            title: epub_file.title(),
            author: epub_file.author(),
            description: None,
            cover_path: epub_file.cover_path(),
            publish_year: None,
            language: None,
            chapter_count: epub_file.spine().len() as i32,
            total_characters: 0,
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_index: i32) -> Result<String,AppError> {
        let mut epub_file = unzip::EpubFile::open(file_path)?;
        let chapters = toc::extract_chapters_from_epub(&mut epub_file);

        let chapter = chapters
            .iter()
            .find(|c| c.chapter_index == chapter_index)
            .ok_or_else(|| {
                AppError::chapter_extract_error(chapter_index, format!("未找到章节 {}", chapter_index))
            })?;

        let spine = epub_file.spine();
        let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
            AppError::chapter_extract_error(chapter.chapter_index, format!("章节索引超出范围：{}", chapter.start_index))
        })?;

        epub_file.read_resource(href)
    }
}

pub fn create_epub_parser() -> Arc<dyn BookParser> {
    Arc::new(EpubParser::new())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_epub_parser_name() {
        let parser = EpubParser::new();
        assert_eq!(parser.name(), "EPUB Parser");
    }

    #[test]
    fn test_epub_parser_supported_formats() {
        let parser = EpubParser::new();
        let formats = parser.supported_formats();
        assert!(formats.contains(&"epub"));
    }

    #[test]
    fn test_epub_parser_supports_format() {
        let parser = EpubParser::new();
        assert!(parser.supports_format("epub"));
        assert!(parser.supports_format("EPUB"));
        assert!(!parser.supports_format("txt"));
    }

    #[test]
    fn test_epub_parser_parse_file_not_found() {
        let parser = EpubParser::new();
        let result = parser.parse("non_existent.epub");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
