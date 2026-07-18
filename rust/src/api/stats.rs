//! 阅读统计 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::stats::stats_repo::StatsRepository;
use crate::domain::stats::{GlobalStats, ReadingStats};
use crate::infra::manager::storage_pool;
use chrono::NaiveDate;
/// 获取今日阅读统计数据
#[frb]
pub async fn get_today_reading_stats() -> Result<Vec<ReadingStats>, AppError> {
    tracing::debug!("[stats] get_today_reading_stats");
    let pool = storage_pool()?;
    StatsRepository::find_by_today(&pool).await
}

/// 获取日期范围内的阅读统计数据
#[frb]
pub async fn get_reading_stats_by_range(
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingStats>, AppError> {
    let start = NaiveDate::parse_from_str(&start_date, "%Y-%m-%d").map_err(|e| {
        AppError::InternalError {
            reason: e.to_string(),
        }
    })?;
    let end =
        NaiveDate::parse_from_str(&end_date, "%Y-%m-%d").map_err(|e| AppError::InternalError {
            reason: e.to_string(),
        })?;
    let pool = storage_pool()?;
    StatsRepository::find_by_range(&pool, start, end).await
}

/// 获取全局阅读统计信息
#[frb]
pub async fn get_global_reading_stats() -> Result<GlobalStats, AppError> {
    tracing::debug!("[stats] get_global_reading_stats");
    let pool = storage_pool()?;
    StatsRepository::find_by_global(&pool).await
}

/// 获取最近 N 天的阅读统计数据
#[frb]
pub async fn get_reading_stats_by_days(days: i32) -> Result<Vec<ReadingStats>, AppError> {
    let pool = storage_pool()?;
    StatsRepository::find_by_days(&pool, days).await
}

/// 获取最近 N 天的阅读统计数据（自动填充缺失日期）
#[frb]
pub async fn get_reading_stats_by_days_with_fill(days: i32) -> Result<Vec<ReadingStats>, AppError> {
    let pool = storage_pool()?;
    StatsRepository::find_by_days_with_fill(&pool, days).await
}

/// 更新每日统计数据
#[frb]
pub async fn update_daily_stats(stats: ReadingStats) -> Result<(), AppError> {
    tracing::info!("[stats] update_daily_stats: date={}", stats.date);
    let pool = storage_pool()?;
    StatsRepository::update_by_daily(&pool, &stats).await
}
