//! TXT 解析模块
//! 负责 TXT 文件的编码检测、解码、章节提取、按需内容提供

pub mod decode;
pub mod parse;
pub mod provider;

use flutter_rust_bridge::frb;

use crate::domain::{AppError, ParseResult};
use crate::parser::book_parser::BookMetadata;
use crate::text::chapter_detect::extract_chapters;

pub use parse::parse_txt;
pub use provider::TxtContentProvider;

/// TXT 文件解析器
#[derive(Clone, Copy)]
#[frb(opaque)]
pub struct TxtParser;

impl TxtParser {
    pub fn new() -> Self {
        Self
    }

    pub fn name(&self) -> &'static str {
        "TXT Parser"
    }

    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["txt", "text"]
    }

    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || parse_txt(fp))
            .await
            .map_err(|e| AppError::internal(format!("parse task failed: {}", e)))?
    }

    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let fp = file_path.to_string();
        let result = tokio::task::spawn_blocking(move || parse_txt(fp))
            .await
            .map_err(|e| AppError::internal(format!("parse task failed: {}", e)))??;
        Ok(BookMetadata {
            title: result.book_info.title,
            author: result.book_info.author.unwrap_or_default(),
            description: result.book_info.description,
            cover_path: None,
            publisher: None,
            translator: None,
            isbn: None,
            publish_year: None,
            language: None,
            chapter_count: result.book_info.chapter_count,
            total_characters: result.book_info.total_characters,
        })
    }

    pub async fn extract_chapter(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<String, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || {
            let content = decode::decode_file(&fp)?;
            let chapters = extract_chapters(&content, 1000, "");

            let chapter = chapters
                .iter()
                .find(|c| c.chapter_index == chapter_index)
                .ok_or_else(|| {
                    AppError::chapter_extract_error(
                        chapter_index,
                        format!("chapter {} not found", chapter_index),
                    )
                })?;

            let start = chapter.start_index as usize;
            let end = chapter.end_index as usize;

            if start >= content.len() {
                return Ok(String::new());
            }

            let safe_end = end.min(content.len());

            if !content.is_char_boundary(start) || !content.is_char_boundary(safe_end) {
                tracing::warn!(
                    "chapter boundary is not a valid UTF-8 char boundary: start={}, end={}",
                    start,
                    safe_end
                );
                return Err(AppError::chapter_extract_error(
                    0,
                    format!("invalid chapter boundary: {}-{}", start, safe_end),
                ));
            }

            Ok(content[start..safe_end].to_string())
        })
        .await
        .map_err(|e| AppError::internal(format!("chapter extraction failed: {}", e)))?
    }
}

impl Default for TxtParser {
    fn default() -> Self {
        Self::new()
    }
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

    #[tokio::test]
    async fn test_txt_parser_parse_file_not_found() {
        let parser = TxtParser::new();
        let result = parser.parse("non_existent.txt").await;
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }

    #[tokio::test]
    async fn test_txt_parser_extract_metadata() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("三体.txt");
        let content = "书名：三体\n作者：刘慈欣\n\n第一章 开始\n这是测试内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let metadata = parser
            .extract_metadata(file_path.to_str().unwrap())
            .await
            .unwrap();

        assert_eq!(metadata.title, "三体");
        assert_eq!(metadata.author, "刘慈欣");
        assert_eq!(metadata.chapter_count, 1);
        assert!(metadata.total_characters > 0);
    }

    #[tokio::test]
    async fn test_txt_parser_extract_metadata_filename_fallback() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("novel.txt");
        let content = "这是纯文本内容，没有章节标题也没有元数据。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let metadata = parser
            .extract_metadata(file_path.to_str().unwrap())
            .await
            .unwrap();

        // 无元数据时使用文件名作为书名
        assert_eq!(metadata.title, "novel");
        assert_eq!(metadata.author, "Unknown Author");
        assert_eq!(metadata.chapter_count, 1);
    }

    #[tokio::test]
    async fn test_txt_parser_extract_chapter() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        let content = "第一章 开始\n这是第一章的内容。\n\n第二章 结束\n这是第二章的内容。";
        fs::write(&file_path, content).unwrap();

        let parser = TxtParser::new();
        let chapter_content = parser
            .extract_chapter(file_path.to_str().unwrap(), 0)
            .await
            .unwrap();

        assert!(chapter_content.contains("第一章"));
        assert!(chapter_content.contains("这是第一章的内容"));
    }
}
