// ============================================================
// 文件作用：TXT 解析模块，负责 TXT 文件的编码检测、解码、章节提取、按需内容提供。
//
// 公有类型/函数：
//   - TxtParser — TXT 文件解析器（FRB opaque struct）
//   - TxtParser::new() / parse() / extract_metadata()
//   - get_chapter_content_ir() / txt_to_chapter_ir()
//   - parse_txt() — TXT 文件解析入口
//   - TxtContentProvider — TXT 按需内容提供器
//
// 子模块：
//   - content_ir, decode, parse, provider
// ============================================================

//! TXT 解析模块
//! 负责 TXT 文件的编码检测、解码、章节提取、按需内容提供

pub mod content_ir;
pub mod decode;
pub mod parse;
pub mod provider;

use flutter_rust_bridge::frb;

use crate::domain::AppError;
use crate::parser::types::ParseResult;
use crate::parser::BookMetadata;

pub use content_ir::{get_chapter_content_ir, txt_to_chapter_ir};
pub use parse::parse_txt;
pub use provider::TxtContentProvider;

/// TXT 文件解析器
#[derive(Clone, Copy)]
#[frb(opaque)]
pub struct TxtParser;

impl TxtParser {
    /// 创建新的 TXT 解析器
    pub fn new() -> Self {
        Self
    }

    /// 获取解析器名称
    pub fn name(&self) -> &'static str {
        "TXT Parser"
    }

    /// 获取支持的格式列表
    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["txt", "text"]
    }

    /// 解析 TXT 文件
    ///
    /// # 参数
    ///
    /// * `file_path` - TXT 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析结果（含书籍信息和章节列表）
    /// * `Err(AppError)` - 解析失败
    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || parse_txt(fp))
            .await
            .map_err(|e| AppError::InternalError { reason: format!("parse task failed: {}", e) })?
    }

    /// 提取 TXT 文件元数据
    ///
    /// 解析文件内容头部，提取书名、作者等元数据信息。
    ///
    /// # 参数
    ///
    /// * `file_path` - TXT 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(BookMetadata)` - 书籍元数据
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let fp = file_path.to_string();
        let result = tokio::task::spawn_blocking(move || parse_txt(fp))
            .await
            .map_err(|e| AppError::InternalError { reason: format!("parse task failed: {}", e) })??;
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

}
