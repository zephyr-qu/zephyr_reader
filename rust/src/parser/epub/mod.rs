// ============================================================
// 文件作用：EPUB 解析模块，负责 EPUB 文件的解压、结构解析、文本提取、按需内容提供。
//
// 公有类型/函数：
//   - EpubParser — EPUB 文件解析器（FRB opaque struct）
//   - EpubParser::new() / parse() / extract_metadata()
//   - EpubAssetRegistry — 图片 asset 注册表
//   - get_chapter_content_ir() — 获取 EPUB 章节 IR
//   - html_to_chapter_ir() — HTML 片段 → 章 IR
//   - parse_epub() — EPUB 文件解析入口
//
// 子模块：
//   - asset_registry, content_ir, metadata, parse, processed_image, provider, toc, unzip
// ============================================================

//! EPUB 解析模块
//! 负责 EPUB 文件的解压、结构解析、文本提取、按需内容提供

pub mod asset_registry;
pub mod content_ir;
pub mod css;
pub mod parse;
pub mod processed_image;
pub mod provider;
pub mod toc;
pub mod metadata;
pub mod unzip;

pub use asset_registry::{
    canonicalize_chapter_image_assets, EpubAssetEntry, EpubAssetRegistry, normalize_asset_id,
    resolve_relative_href,
};
pub use content_ir::{get_chapter_content_ir, html_to_chapter_ir};
pub use metadata::{EpubMetadata, EpubTocItem, ParseResult};

use std::path::Path;

use flutter_rust_bridge::frb;

use crate::domain::AppError;
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
            .map_err(|e| AppError::InternalError { reason: format!("EPUB parse task failed: {}", e) })?
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
                return Err(AppError::FileNotFound { path: fp });
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
        .map_err(|e| AppError::InternalError { reason: format!("EPUB metadata extraction failed: {}", e) })?
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
