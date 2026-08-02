// ============================================================
// 文件作用：EPUB 解析模块，负责 EPUB 文件的解压、结构解析与元数据提取。
//
// 公有类型/函数：
//   - EpubParser — EPUB 文件解析器（FRB opaque struct）
//   - EpubParser::new() / parse()
//   - parse_epub() — EPUB 文件解析入口
//
// 子模块：
//   - archive_reader, asset_registry, entry_extractor, parse, toc
// ============================================================

//! EPUB 解析模块
//! 负责 EPUB 文件的解压、结构解析与元数据提取

pub mod archive_reader;
pub mod asset_registry;
pub mod entry_extractor;
pub mod parse;
pub mod toc;

use flutter_rust_bridge::frb;

use crate::domain::AppError;
use crate::parser::types::ParseResult;

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
            .map_err(|e| AppError::InternalError {
                reason: format!("EPUB parse task failed: {}", e),
            })?
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
