// ============================================================
// 文件作用：搜索类型 + 搜索索引统计
//
// 公有类型/函数：
//   - struct SearchResult — 搜索结果
//   - struct IndexStats — 搜索索引统计
// ============================================================

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

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
