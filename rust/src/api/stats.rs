//! 阅读统计 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::stats::stats_repo::StatsRepository;
use crate::domain::stats::{GlobalStats, ReadingStats};
use crate::infra::manager::storage_pool;

/// 获取全局阅读统计信息
#[frb]
pub async fn get_global_reading_stats() -> Result<GlobalStats, AppError> {
    tracing::debug!("[stats] get_global_reading_stats");
    let pool = storage_pool()?;
    StatsRepository::find_by_global(&pool).await
}

/// 获取最近 N 天的阅读统计数据（自动填充缺失日期）
#[frb]
pub async fn get_reading_stats_by_days_with_fill(days: i32) -> Result<Vec<ReadingStats>, AppError> {
    let pool = storage_pool()?;
    StatsRepository::find_by_days_with_fill(&pool, days).await
}
