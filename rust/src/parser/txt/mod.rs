//! TXT 解析模块
//! 负责 TXT 文件的编码检测、解码、章节提取

pub mod decode;
pub mod parse;

use std::sync::Arc;

use flutter_rust_bridge::frb;

use crate::domain::{ ParseResult, AppError};
use crate::domain::parser::{BookMetadata, BookParser};
use crate::text::chapter_detect::extract_chapters;

pub use decode::detect_encoding;
pub use parse::parse_txt;

/// TXT 文件解析器
#[frb(opaque)]
pub struct TxtParser;

impl TxtParser {
    pub fn new() -> Self {
        Self
    }
}

impl Default for TxtParser {
    fn default() -> Self {
        Self::new()
    }
}

impl BookParser for TxtParser {
    fn name(&self) -> &str {
        "TXT Parser"
    }

    fn supported_formats(&self) -> Vec<&str> {
        vec!["txt", "text"]
    }

    fn parse(&self, file_path: &str) -> Result<ParseResult,AppError> {
        parse_txt(file_path.to_string())
    }

    fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata,AppError> {
        let result = self.parse(file_path)?;
        Ok(BookMetadata {
            title: result.book_info.title,
            author: result.book_info.author.unwrap_or_default(),
            description: None,
            cover_path: None,
            publish_year: None,
            language: None,
            chapter_count: result.book_info.chapter_count,
            total_characters: result.book_info.total_characters,
        })
    }

    fn extract_chapter(&self, file_path: &str, chapter_index: i32) -> Result<String,AppError> {
        let content = decode::decode_file(file_path)?;
        let chapters = extract_chapters(&content, 1000);

        let chapter = chapters
            .iter()
            .find(|c| c.chapter_index == chapter_index)
            .ok_or_else(|| {
                AppError::chapter_extract_error(chapter_index, format!("未找到章节 {}", chapter_index))
            })?;

        let start = chapter.start_index as usize;
        let end = chapter.end_index as usize;

        if start >= content.len() {
            return Ok(String::new());
        }

        let safe_end = end.min(content.len());

        if !content.is_char_boundary(start) || !content.is_char_boundary(safe_end) {
            tracing::warn!(
                "章节边界不是有效的 UTF-8 字符边界：start={}, end={}",
                start,
                safe_end
            );
            return Err(AppError::chapter_extract_error(0, format!(
                "章节边界无效：{}-{}",
                start, safe_end
            )));
        }

        Ok(content[start..safe_end].to_string())
    }
}

pub fn create_txt_parser() -> Arc<dyn BookParser> {
    Arc::new(TxtParser::new())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_txt_parser_name() {
        let parser = TxtParser::new();
        assert_eq!(parser.name(), "TXT Parser");
    }

    #[test]
    fn test_txt_parser_supported_formats() {
        let parser = TxtParser::new();
        let formats = parser.supported_formats();
        assert!(formats.contains(&"txt"));
        assert!(formats.contains(&"text"));
    }

    #[test]
    fn test_txt_parser_supports_format() {
        let parser = TxtParser::new();
        assert!(parser.supports_format("txt"));
        assert!(parser.supports_format("TXT"));
        assert!(!parser.supports_format("epub"));
    }

    #[test]
    fn test_txt_parser_parse_file_not_found() {
        let parser = TxtParser::new();
        let result = parser.parse("non_existent.txt");
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[test]
    fn test_txt_parser_extract_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n这是测试内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let metadata = parser
            .extract_metadata(file_path.to_str().unwrap())
            .unwrap();

        assert!(metadata.title.contains("第一章"));
        assert_eq!(metadata.chapter_count, 1);
        assert!(metadata.total_characters > 0);
    }

    #[test]
    fn test_txt_parser_extract_chapter() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n这是第一章的内容。\n\n第二章 结束\n这是第二章的内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let chapter_content = parser
            .extract_chapter(file_path.to_str().unwrap(), 0)
            .unwrap();

        assert!(chapter_content.contains("第一章"));
        assert!(chapter_content.contains("这是第一章的内容"));
    }
}
