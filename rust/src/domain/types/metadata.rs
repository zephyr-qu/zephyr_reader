//! 元数据模块 (Metadata)
//!
//! 包含 EPUB、PDF 等格式的元数据结构，以及书籍解析结果。
//! 用于存储书籍的标题、作者、目录、章节信息等元数据。
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

// ==================== PDF 元数据 ====================

/// PDF 元数据
/// 包含 PDF 文档的基本信息
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[frb(non_opaque)]
pub struct PdfMetadata {
    /// 标题
    pub title: Option<String>,
    /// 作者
    pub author: Option<String>,
    /// 主题
    pub subject: Option<String>,
    /// 创建者（软件名称）
    pub creator: Option<String>,
    /// 总页数
    pub page_count: i32,
}

// ==================== 解析结果 ====================

/// 书籍解析结果
/// 包含书籍元数据信息和章节列表
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct ParseResult {
    /// 书籍信息
    pub book_info: Book,
    /// 章节列表
    pub chapters: Vec<Chapter>,
}

/// 文件解析配置
/// 控制解析器的行为
#[derive(Debug, Clone, Default)]
pub struct ParseConfig {
    /// 是否并行解析章节（适用于大文件）
    pub parallel: bool,
}
