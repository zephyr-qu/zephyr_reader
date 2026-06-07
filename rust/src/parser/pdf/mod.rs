//! PDF 解析模块
//! 负责 PDF 文件的解压、结构解析、文本提取、按需内容提供

pub mod images;
pub mod metadata;
pub mod parse;
pub mod provider;
pub mod text;

use std::path::Path;

use flutter_rust_bridge::frb;

use crate::domain::{AppError, ParseResult};
use crate::parser::book_parser::BookMetadata;

pub use images::extract_pdf_cover;
pub use parse::get_pdf_metadata;
pub use parse::parse_pdf;
pub use text::get_chapter_text;

/// 默认每章包含的页数
pub const DEFAULT_PAGES_PER_CHAPTER: usize = 10;

/// PDF 文件解析器
#[derive(Clone, Copy)]
#[frb(opaque)]
pub struct PdfParser;

impl PdfParser {
    /// 创建新的 PDF 解析器
    pub fn new() -> Self {
        Self
    }

    /// 获取解析器名称
    pub fn name(&self) -> &'static str {
        "PDF Parser"
    }

    /// 获取支持的格式列表
    pub fn supported_formats(&self) -> Vec<&str> {
        vec!["pdf"]
    }

    /// 解析 PDF 文件
    ///
    /// PDF 章节按页数划分，每 10 页为一章（可配置）。
    ///
    /// # 参数
    ///
    /// * `file_path` - PDF 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(ParseResult)` - 解析结果（含书籍信息和章节列表）
    /// * `Err(AppError)` - 解析失败
    pub async fn parse(&self, file_path: &str) -> Result<ParseResult, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || parse_pdf(fp))
            .await
            .map_err(|e| AppError::internal(format!("PDF parse task failed: {}", e)))?
    }

    /// 提取 PDF 文件元数据
    ///
    /// 从 PDF /Info 字典中提取标题、作者等元数据信息。
    ///
    /// # 参数
    ///
    /// * `file_path` - PDF 文件路径
    ///
    /// # 返回值
    ///
    /// * `Ok(BookMetadata)` - 书籍元数据
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_metadata(&self, file_path: &str) -> Result<BookMetadata, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || -> Result<BookMetadata, AppError> {
            if !Path::new(&fp).exists() {
                return Err(AppError::file_not_found(&fp));
            }

            let metadata = get_pdf_metadata(fp.clone())?;

            let title = metadata.title.clone().unwrap_or_else(|| {
                Path::new(&fp)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("Unknown Book")
                    .to_string()
            });

            Ok(BookMetadata {
                title,
                author: metadata
                    .author
                    .unwrap_or_else(|| "Unknown Author".to_string()),
                description: None,
                cover_path: None,
                publisher: None,
                translator: None,
                isbn: None,
                publish_year: None,
                language: None,
                total_characters: 0,
                chapter_count: 0,
            })
        })
        .await
        .map_err(|e| AppError::internal(format!("PDF metadata extraction failed: {}", e)))?
    }

    /// 提取指定章节内容
    ///
    /// 按每章页数划分，提取对应页面的文本。
    ///
    /// # 参数
    ///
    /// * `file_path` - PDF 文件路径
    /// * `chapter_index` - 章节索引（从 0 开始）
    ///
    /// # 返回值
    ///
    /// * `Ok(String)` - 章节文本内容
    /// * `Err(AppError)` - 提取失败
    pub async fn extract_chapter(
        &self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<String, AppError> {
        let fp = file_path.to_string();
        tokio::task::spawn_blocking(move || {
            let start_page = (chapter_index as usize * DEFAULT_PAGES_PER_CHAPTER) as u32;
            let end_page = ((chapter_index as usize + 1) * DEFAULT_PAGES_PER_CHAPTER) as u32;
            get_chapter_text(&fp, start_page as usize, end_page as usize)
        })
        .await
        .map_err(|e| AppError::internal(format!("PDF chapter extraction failed: {}", e)))?
    }
}

impl Default for PdfParser {
    fn default() -> Self {
        Self::new()
    }
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

    #[tokio::test]
    async fn test_pdf_parser_parse_file_not_found() {
        let parser = PdfParser::new();
        let result = parser.parse("non_existent.pdf").await;
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(err, AppError::FileNotFound { .. }),
            "Expected FileNotFound error, got: {:?}",
            err
        );
    }
}
