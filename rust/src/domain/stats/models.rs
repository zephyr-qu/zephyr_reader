//! 备份数据模型

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 按日聚合阅读统计（来自 reading_sessions 直算，无书粒度）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct DailyReadingStats {
    pub date: String,
    pub reading_time_seconds: i64,
    pub session_count: i64,
    #[sqlx(default)]
    pub last_session_id: Option<String>,
}
/// 全局阅读统计汇总（应用层计算，非直接 DB 映射）

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(non_opaque, dart_metadata = ("freezed"))]
pub struct GlobalStats {
    pub total_reading_time_seconds: i64,
    pub books_read_count: i64,
    pub books_completed_count: i64,
    /// Rust 侧后计算字段：SQL 聚合不含，需显式赋值。
    #[sqlx(default)]
    pub consecutive_reading_days: i64,
    pub today_reading_time_seconds: i64,
    pub total_books_count: i64,
    pub total_notes_count: i64,
    pub total_bookmarks_count: i64,
}
