use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 单章阅读进度
///
/// 进度只持久化 chapterIndex + charOffset（ADR-001 / I1）。
/// page_index / total_pages 已移除——它们是分页视图的派生值，不属于持久化真理。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingProgress {
    pub book_id: String,
    pub chapter_index: i64,
    pub chunk_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub progress: f32,
    pub reading_time_seconds: i64,
    pub last_read_at: DateTime<Utc>,
    pub is_completed: bool,
}

impl ReadingProgress {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        chunk_index: i64,
        char_offset: i64,
        progress: f32,
        reading_time_seconds: i64,
        is_completed: bool,
    ) -> Self {
        Self {
            book_id: book_id.to_string(),
            chapter_index,
            chunk_index,
            chapter_id: None,
            char_offset,
            progress,
            reading_time_seconds,
            last_read_at: Utc::now(),
            is_completed,
        }
    }
}
