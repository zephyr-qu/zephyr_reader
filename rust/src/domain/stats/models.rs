//! 备份数据模型

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 每日阅读统计
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingStats {
    pub book_id: String,
    pub date: String,
    pub reading_time_seconds: i64,
    pub characters_read: i64,
    pub session_count: i64,
    #[sqlx(default)]
    pub last_session_id: Option<String>,
}
/// 单次聚合查询获取所有计数与求和指标。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque)]
pub struct AggregatedStats {
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read_count: i64,
    pub books_completed_count: i64,
    pub total_books_count: i64,
    pub total_notes_count: i64,
    pub total_bookmarks_count: i64,
    pub today_reading_time_seconds: i64,
    pub today_characters_read: i64,
}
/// 全局阅读统计汇总（应用层计算，非直接 DB 映射）

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque, dart_metadata = ("freezed"))]
pub struct GlobalStats {
    pub total_reading_time_seconds: i64,
    pub total_characters_read: i64,
    pub books_read_count: i64,
    pub books_completed_count: i64,
    pub consecutive_reading_days: i64,
    pub today_reading_time_seconds: i64,
    pub today_characters_read: i64,
    pub average_reading_speed: f32,
    pub total_books_count: i64,
    pub total_notes_count: i64,
    pub total_bookmarks_count: i64,
}
