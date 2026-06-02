//! 分页内容模块 (Pagination)
//!
//! 包含分页相关的结构体：页面内容、页面偏移量等。
//! 用于排版引擎计算和存储页面的分页信息。

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

// ==================== 分页内容 ====================

/// 分页内容
/// 表示单个页面的文本内容
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct PageContent {
    /// 章节索引
    pub chapter_index: i32,
    /// 页面索引（从 0 开始）
    pub page_index: i32,
    /// 页面文本内容
    pub content: String,
    /// 是否为最后一页
    pub is_last_page: bool,
    /// 此页在章节原文中的起始字节偏移（用于阅读进度定位）
    pub start_offset: i64,
    /// 此页在章节原文中的结束字节偏移
    pub end_offset: i64,
}

// ==================== 页面偏移量 ====================

/// 页面偏移量
/// 记录页面在源文件中的位置范围
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PageOffset {
    /// 起始偏移量（字节）
    pub offset: i64,
    /// 内容长度（字节）
    pub length: i64,
}

/// 搜索结果
///
/// 表示一次搜索匹配的详细信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct SearchResult {
    /// 书籍 ID
    pub book_id: String,
    /// 章节 ID
    pub chapter_id: String,
    pub chapter_index: String,
    /// 章节标题
    pub chapter_title: String,
    /// 匹配内容的片段（上下文）
    pub snippet: String,
    /// 匹配位置（在章节中的字符偏移）
    pub position: i64,
    /// 相关性得分（越高越相关）
    pub score: f32,
    /// 字符偏移量（用于定位高亮）
    pub char_offset: i64,
}
