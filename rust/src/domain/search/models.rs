//! 搜索领域模型

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 搜索结果
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct SearchResult {
    pub book_id: String,
    pub chapter_id: String,
    #[sqlx(try_from = "i64")]
    pub chapter_index: i32,
    pub chapter_title: String,
    pub snippet: String,
    pub position: i32,
    pub score: f32,
    pub char_offset: i32,
}

/// 搜索索引统计信息
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
#[frb]
pub struct IndexStats {
    pub total_chunks: i64,
    pub indexed_books: i64,
    pub indexed_chapters: i64,
}
