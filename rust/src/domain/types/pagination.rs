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
    pub start_offset: i32,
    /// 此页在章节原文中的结束字节偏移（用于阅读进度定位）
    pub end_offset: i32,
    /// 此页在富文本段落列表中的起始段落索引（用于富文本渲染）
    pub first_paragraph_index: i32,
    /// 此页在富文本段落列表中的结束段落索引（用于富文本渲染）
    pub last_paragraph_index: i32,
}

// ==================== 页面描述符 ====================

/// 页面描述符（轻量级，不含页面文本内容）
/// 用于分页排版时仅返回页面偏移信息，按需获取页面内容。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, bincode::Encode, bincode::Decode)]
#[frb(non_opaque)]
pub struct PageDescriptor {
    /// 页面索引（从 0 开始）
    pub page_index: i32,
    /// 此页在章节原文中的起始字节偏移
    pub start_offset: i32,
    /// 此页在章节原文中的结束字节偏移
    pub end_offset: i32,
    /// 此页在富文本段落列表中的起始段落索引（用于富文本渲染）
    pub first_paragraph_index: i32,
    /// 此页在富文本段落列表中的结束段落索引（用于富文本渲染）
    pub last_paragraph_index: i32,
    /// 是否为最后一页
    pub is_last_page: bool,
}

/// 章节分页引擎模式（Phase 2 M3）。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[frb]
pub enum ChapterPaginationMode {
    /// Phase 1 plain 文本流。
    #[default]
    PlainText,
    /// Phase 2 块 IR + `BlockPaginator`（含 Image 块时启用）。
    ContentBlocks,
}

/// 分页结果（包含页面描述符列表和配置哈希）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(non_opaque)]
pub struct PaginateResult {
    /// 页面描述符列表
    pub descriptors: Vec<PageDescriptor>,
    /// 排版配置哈希，用于后续按需获取页面内容
    pub config_hash: u64,
    /// 是否为部分分页（true=仅前 N 字符，需后续补全）
    pub is_partial: bool,
    /// 分页引擎模式；`ContentBlocks` 时须用 `get_session_page_blocks` 取块。
    pub mode: ChapterPaginationMode,
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
    /// 章节索引
    #[sqlx(try_from = "i64")]
    pub chapter_index: i32,
    /// 章节标题
    pub chapter_title: String,
    /// 匹配内容的片段（上下文）
    pub snippet: String,
    /// 匹配位置（在章节中的字符偏移）
    pub position: i32,
    /// 匹配得分（相关性排序）
    pub score: f32,
    /// 匹配所在的字符偏移（精确位置）
    pub char_offset: i32,
}

/// 搜索索引统计信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb]
pub struct IndexStats {
    /// 索引块总数（按 SEARCH_CHUNK_SIZE 分块后的文档数）
    pub total_chunks: i64,
    /// 已建索引的书籍数
    pub indexed_books: i64,
    /// 已建索引的章节数
    pub indexed_chapters: i64,
}
