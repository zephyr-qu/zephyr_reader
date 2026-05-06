//! EPUB 文件解析器实现
//!
//! 实现 `BookParser` trait，提供 EPUB 文件格式的解析支持。

use std::path::Path;
use std::sync::Arc;

use crate::ffi::{ApiResult, ParseResult, ParserError};
use crate::parser::traits::{BookMetadata, BookParser};

/// EPUB 文件解析器
pub struct EpubParser {}

impl EpubParser {
    /// 创建新的 EPUB 解析器实例
    pub fn new() -> Self {
        Self {}
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

    fn parse(&self, file_path: &str) -> ApiResult<ParseResult> {
        crate::parser::parse_epub(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> ApiResult<BookMetadata> {
        use crate::parser::epub::unzip::EpubFile;

        if !Path::new(file_path).exists() {
            return Err(ParserError::file_not_found(file_path));
        }

        let epub_file = EpubFile::open(file_path)?;

        Ok(BookMetadata {
            title: epub_file.title(),
            author: epub_file.author(),
            description: None,
            cover_path: epub_file.cover_path(),
            publish_year: None,
            language: None,
            chapter_count: epub_file.spine().len() as i32,
            total_characters: 0, // 需要读取所有章节才能计算
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_id: i32) -> ApiResult<String> {
        use crate::parser::epub::unzip::EpubFile;

        let mut epub_file = EpubFile::open(file_path)?;
        let chapters = crate::parser::epub::toc::extract_chapters_from_epub(&mut epub_file);

        let chapter = chapters
            .iter()
            .find(|c| c.index == chapter_id)
            .ok_or_else(|| {
                ParserError::ChapterExtractError(format!("未找到章节 {}", chapter_id))
            })?;

        // EPUB 章节的 start_index 存储的是 spine 中的索引
        let spine = epub_file.spine();
        let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
            ParserError::ChapterExtractError(format!("章节索引超出范围：{}", chapter.start_index))
        })?;

        epub_file.read_resource(href)
    }
}

/// 创建 EPUB 解析器实例（方便外部使用）
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
            matches!(err, ParserError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
