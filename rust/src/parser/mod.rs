//! 解析器模块
//! 管理 EPUB、TXT 格式解析

pub mod book_parser;
pub mod cover_extractor;
pub mod epub;
pub mod provider;
pub mod registry;
pub mod txt;

/// 获取封面提取器注册表。
pub use cover_extractor::get_cover_registry;

use crate::domain::{AppError, ParseResult};
use crate::parser::book_parser::BookMetadata;
use crate::parser::epub::EpubParser;
use crate::parser::txt::TxtParser;

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

    pub async fn extract_chapter(
        self,
        file_path: &str,
        chapter_index: i32,
    ) -> Result<String, AppError> {
        match self {
            Parser::Txt(p) => p.extract_chapter(file_path, chapter_index).await,
            Parser::Epub(_) => Err(AppError::UnsupportedFormat { format: "epub".into() }),
        }
    }
}
