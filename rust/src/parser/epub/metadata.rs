// ============================================================
// 文件作用：EPUB 元数据结构、目录项、书籍解析结果
//
// 原路径：src/domain/types/metadata.rs
// 迁移至：src/parser/epub/metadata.rs
//
// 公有类型/函数：
//   - struct EpubMetadata — EPUB 元数据（标题、作者、封面、目录）
//   - struct EpubTocItem — EPUB 目录项
//   - struct ParseResult — 书籍解析结果（Book + 章节列表）
// ============================================================
use crate::storage::models::{Book, Chapter};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

// ==================== EPUB 元数据 ====================

/// EPUB 元数据
/// 包含书籍标题、作者、封面、目录等信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubMetadata {
    /// 书籍标题
    pub title: String,
    /// 作者
    pub author: String,
    /// 封面图片路径
    pub cover_path: Option<String>,
    /// 目录列表
    pub toc: Vec<EpubTocItem>,
    /// 阅读顺序（spine 中的章节 ID 列表）
    pub spine: Vec<String>,
}

/// EPUB 目录项
/// 表示目录中的一个条目
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct EpubTocItem {
    /// 显示标签
    pub label: String,
    /// 链接地址（href）
    pub href: String,
    /// 层级深度（从 0 开始）
    pub level: i32,
}

// ==================== 解析结果 ====================

/// 书籍解析结果
/// 包含书籍元数据信息和章节列表
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParseResult {
    /// 书籍信息
    pub book_info: Book,
    /// 章节列表
    pub chapters: Vec<Chapter>,
}
