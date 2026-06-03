//! EPUB 解析模块
//! 负责 EPUB 文件的解压、结构解析、文本提取、按需内容提供

pub mod parse;
pub mod provider;
pub mod toc;
pub mod unzip;

use std::path::Path;

use flutter_rust_bridge::frb;

use crate::domain::{AppError, ParseResult};
use crate::parser::book_parser::BookMetadata;

pub use parse::parse_epub;

/// EPUB 文件解析器
#[derive(Clone, Copy)]
#[frb(opaque)]
pub struct EpubParser;

impl EpubParser {
    pub fn new() -> Self {
        Self
    }

    pub fn name(&self) -> &'static str {
        "EPUB Parser"
    }

    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["epub"]
    }

    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || parse_epub(fp))
            .await
            .map_err(|e| AppError::internal(format!("EPUB parse task failed: {}", e)))?
    }

    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || -> Result<BookMetadata, AppError> {
            if !Path::new(&fp).exists() {
                return Err(AppError::file_not_found(&fp));
            }

            let epub_file = unzip::EpubFile::open(&fp)?;

            let publisher = epub_file.publisher();
            let translator = epub_file.translator();
            let isbn = epub_file.identifier();

            Ok(BookMetadata {
                title: epub_file.title(),
                author: epub_file.author(),
                description: None,
                cover_path: epub_file.cover_path(),
                publisher,
                translator,
                isbn,
                publish_year: None,
                language: None,
                chapter_count: epub_file.spine().len() as i32,
                total_characters: 0,
            })
        })
        .await
        .map_err(|e| AppError::internal(format!("EPUB metadata extraction failed: {}", e)))?
    }

    pub async fn extract_chapter(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<String, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || -> Result<String, AppError> {
            let mut epub_file = unzip::EpubFile::open(&fp)?;
            let chapters = toc::extract_chapters_from_epub(&mut epub_file, "");

            let chapter = chapters
                .iter()
                .find(|c| c.chapter_index == chapter_index)
                .ok_or_else(|| {
                    AppError::chapter_extract_error(
                        chapter_index,
                        format!("chapter {} not found", chapter_index),
                    )
                })?;

            let spine = epub_file.spine();
            let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
                AppError::chapter_extract_error(
                    chapter.chapter_index,
                    format!("chapter index out of range: {}", chapter.start_index),
                )
            })?;

            epub_file.read_resource(href)
        })
        .await
        .map_err(|e| AppError::internal(format!("EPUB chapter extraction failed: {}", e)))?
    }
}

impl Default for EpubParser {
    fn default() -> Self {
        Self::new()
    }
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

    #[tokio::test]
    async fn test_epub_parser_parse_file_not_found() {
        let parser = EpubParser::new();
        let result = parser.parse("non_existent.epub").await;
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
