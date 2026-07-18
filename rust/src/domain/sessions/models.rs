use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 单次连续阅读会话记录
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingSession {
    pub id: String,
    pub book_id: String,
    pub chapter_index: i64,
    pub start_char_offset: i64,
    pub end_char_offset: i64,
    pub started_at: DateTime<Utc>,
    pub ended_at: DateTime<Utc>,
    pub duration_seconds: i64,
}
impl ReadingSession {
    /// 创建阅读会话（结束时调用）
    ///
    /// - `id` / `started_at` / `ended_at` / `duration_seconds` 由构造函数自动计算
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        start_char_offset: i64,
        end_char_offset: i64,
        started_at: DateTime<Utc>,
    ) -> Self {
        let ended_at = Utc::now();
        let duration_seconds = (ended_at - started_at).num_seconds().max(0);
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            book_id: book_id.to_string(),
            chapter_index,
            start_char_offset,
            end_char_offset: end_char_offset.max(start_char_offset),
            started_at,
            ended_at,
            duration_seconds,
        }
    }
}
