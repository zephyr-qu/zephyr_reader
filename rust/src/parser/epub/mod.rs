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
    /// 创建新的 EPUB 解析器
    pub fn new() -> Self {
        Self
    }

    /// 获取解析器名称
    pub fn name(&self) -> &'static str {
        "EPUB Parser"
    }

    /// 获取支持的格式列表
    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["epub"]
    }

    /// 解析 EPUB 文件
    ///
    /// 解压 EPUB 并提取元数据、章节列表和目录信息。
    ///
    /// # 参数
    ///
    /// * `file_path` - EPUB 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析结果（含书籍信息和章节列表）
    /// * `Err(AppError)` - 解析失败
    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || parse_epub(fp))
            .await
            .map_err(|e| AppError::InternalError { reason: format!("EPUB parse task failed: {}", e).into() })?
    }

    /// 提取 EPUB 文件元数据
    ///
    /// 快速获取 EPUB 文件的基本元数据（书名、作者、封面、出版商等），
    /// 无需完整解析章节内容。
    ///
    /// # 参数
    ///
    /// * `file_path` - EPUB 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(BookMetadata)` - 书籍元数据
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || -> Result<BookMetadata, AppError> {
            if !Path::new(&fp).exists() {
                return Err(AppError::FileNotFound { path: fp.into() });
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
                chapter_count: epub_file.spine().len() as i64,
                total_characters: 0,
            })
        })
        .await
        .map_err(|e| AppError::InternalError { reason: format!("EPUB metadata extraction failed: {}", e).into() })?
    }

    /// 提取指定章节内容
    ///
    /// # 参数
    ///
    /// * `file_path` - EPUB 文件路径
    /// * `chapter_index` - 章节索引（从 0 开始）
    ///
    /// # 返回值
    ///
    /// * `Ok(String)` - 章节 HTML 内容
    /// * `Err(AppError)` - 提取失败
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
                .find(|c| c.chapter_index == chapter_index as i64)
                .ok_or_else(|| {
                    AppError::ChapterExtractError { index: chapter_index, reason: format!("chapter {} not found", chapter_index).into() }
                })?;

            let spine = epub_file.spine();
            let href = spine.get(chapter.start_index as usize).ok_or_else(|| {
                AppError::ChapterExtractError { index: (chapter.chapter_index as i64).try_into().unwrap(), reason: format!("chapter index out of range: {}", chapter.start_index).into() }
            })?;

            epub_file.read_resource(href)
        })
        .await
        .map_err(|e| AppError::InternalError { reason: format!("EPUB chapter extraction failed: {}", e).into() })?
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
