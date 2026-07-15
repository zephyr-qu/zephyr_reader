// ============================================================
// 文件作用：解析器公共类型 — 跨子模块共享的数据类型集中于此
//
// 公有类型：
//   - BookMetadata — 书籍元数据（FFI 导出）
//   - Parser — 解析器枚举（Txt / Epub），含 name / supported_formats / parse / extract_metadata
//   - ParseResult — 书籍解析结果（Book + 章节列表）
// ============================================================

//! 解析器公共类型

use flutter_rust_bridge::frb;

use crate::domain::AppError;
use crate::domain::book::Book;
use crate::domain::chapter::Chapter;
use crate::parser::epub::EpubParser;
use crate::parser::txt::TxtParser;

// ==================== 书籍元数据 ====================

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

// ==================== 解析器枚举 ====================

/// 解析器枚举，统一封装各格式解析器
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

// ==================== 解析结果 ====================

/// 书籍解析结果
/// 包含书籍元数据信息和章节列表
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ParseResult {
    /// 书籍信息
    pub book_info: Book,
    /// 章节列表
    pub chapters: Vec<Chapter>,
}
