// ============================================================
// 文件作用：解析器公共类型 — 跨子模块共享的数据类型集中于此
//
// 公有类型：
//   - Parser — 解析器枚举（Epub），含 name / supported_formats / parse
//   - ParseResult — 书籍解析结果（Book + 章节列表）
// ============================================================

//! 解析器公共类型

use crate::domain::AppError;
use crate::domain::book::Book;
use crate::domain::chapter::Chapter;
use crate::parser::epub::EpubParser;

// ==================== 解析器枚举 ====================

/// 解析器枚举，统一封装各格式解析器
#[derive(Clone, Copy)]
pub enum Parser {
    Epub(EpubParser),
}

impl Parser {
    pub fn name(self) -> &'static str {
        "EPUB Parser"
    }

    pub fn supported_formats(self) -> &'static [&'static str] {
        &["epub"]
    }

    pub async fn parse(self, file_path: &str) -> Result<ParseResult, AppError> {
        match self {
            Parser::Epub(p) => p.parse(file_path).await,
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
