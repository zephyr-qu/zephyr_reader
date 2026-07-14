// ============================================================
// 文件作用：解析器模块，管理 EPUB、TXT 格式解析的 Parser 枚举统一封装。
//
// 公有类型/函数：
//   - Parser — 解析器枚举（Txt / Epub）
//   - Parser::name() — 获取解析器名称
//   - Parser::supported_formats() — 获取支持的格式列表
//   - Parser::parse() — 解析文件
//   - Parser::extract_metadata() — 提取元数据
//   - get_cover_registry() — 获取封面提取器注册表
//
// 子模块：
//   - bilingual, cover_extractor, epub, provider, registry, txt
// ============================================================

//! 解析器模块
//! 管理 EPUB、TXT 格式解析

pub mod bilingual;
pub mod cover_extractor;
pub mod epub;
pub mod provider;
pub mod registry;
pub mod txt;

use flutter_rust_bridge::frb;

/// 获取封面提取器注册表。
pub use cover_extractor::get_cover_registry;

use crate::domain::AppError;
use crate::parser::epub::ParseResult;
use crate::parser::epub::EpubParser;
use crate::parser::txt::TxtParser;

/// 书籍元数据，用于 Dart FFI 交互
#[derive(Debug, Clone, Default)]
#[frb]
pub struct BookMetadata {
    pub title: String,
    pub author: String,
    pub description: Option<String>,
    pub cover_path: Option<String>,
    pub publisher: Option<String>,
    pub translator: Option<String>,
    pub isbn: Option<String>,
    pub publish_year: Option<i32>,
    pub language: Option<String>,
    pub chapter_count: i64,
    pub total_characters: i64,
}

/// 解析器枚举，统一封裝各格式解析器
#[derive(Clone, Copy)]
pub enum Parser {
    Txt(TxtParser),
    Epub(EpubParser),
}

impl Parser {
    pub fn name(self) -> &'static str {
        match self {
            Parser::Txt(_) => "TXT Parser",
            Parser::Epub(_) => "EPUB Parser",
        }
    }

    pub fn supported_formats(self) -> &'static [&'static str] {
        match self {
            Parser::Txt(_) => &["txt", "text"],
            Parser::Epub(_) => &["epub"],
        }
    }

    pub async fn parse(self, file_path: &str) -> Result<ParseResult, AppError> {
        match self {
            Parser::Txt(p) => p.parse(file_path).await,
            Parser::Epub(p) => p.parse(file_path).await,
        }
    }

    pub async fn extract_metadata(self, file_path: &str) -> Result<BookMetadata, AppError> {
        match self {
            Parser::Txt(p) => p.extract_metadata(file_path).await,
            Parser::Epub(p) => p.extract_metadata(file_path).await,
        }
    }

}
