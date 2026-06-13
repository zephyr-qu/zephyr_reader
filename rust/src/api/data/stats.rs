//! 阅读统计 API
//!
//! 提供阅读时间、页数等统计数据查询功能。

use chrono::NaiveDate;
use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::StatsRepository;

pub use crate::storage::models::{GlobalStats, ReadingStats};

/// 获取今日阅读统计数据列表
///
/// # 返回
/// 今日的阅读统计数据列表
#[frb]
pub async fn get_today_reading_stats() -> Result<Vec<ReadingStats>, AppError> {
    tracing::debug!("[stats] get_today_reading_stats");
    async_storage!(|pool| StatsRepository::find_by_today(pool))
}

/// 获取日期范围内的阅读统计数据
///
/// # 参数
/// * `start_date` - 开始日期 (格式: YYYY-MM-DD)
/// * `end_date` - 结束日期 (格式: YYYY-MM-DD)
///
/// # 返回
/// 日期范围内的阅读统计数据列表
#[frb]
pub async fn get_reading_stats_by_range(
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingStats>, AppError> {
    // 解析日期
    let start = NaiveDate::parse_from_str(&start_date, "%Y-%m-%d")
        .map_err(|e| AppError::internal(e.to_string()))?;
    let end = NaiveDate::parse_from_str(&end_date, "%Y-%m-%d")
        .map_err(|e| AppError::internal(e.to_string()))?;
    async_storage!(|pool| StatsRepository::find_by_range(pool, start, end))
}

/// 获取全局阅读统计信息
///
/// # 返回
/// 全局阅读统计汇总信息
#[frb]
pub async fn get_global_reading_stats() -> Result<GlobalStats, AppError> {
    tracing::debug!("[stats] get_global_reading_stats");
    async_storage!(|pool| StatsRepository::find_by_global(pool))
}

/// 更新每日统计数据
///
/// # 参数
/// * `stats` - 每日统计数据对象
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn update_daily_stats(stats: ReadingStats) -> Result<(), AppError> {
    tracing::info!("[stats] update_daily_stats: date={}", stats.date);
    async_storage!(|pool| StatsRepository::update_by_daily(pool, &stats))
}

/// 获取最近N天的阅读统计数据
///
/// # 参数
/// * `days` - 天数
///
/// # 返回
/// 最近N天的阅读统计数据列表
#[frb]
pub async fn get_reading_stats_by_days(days: i32) -> Result<Vec<ReadingStats>, AppError> {
    async_storage!(|pool| StatsRepository::find_by_days(pool, days))
}

/// 获取最近N天的阅读统计数据(自动填充缺失日期)
///
/// # 参数
/// * `days` - 天数
///
/// # 返回
/// 最近N天的阅读统计数据列表(缺失日期会自动填充0值记录)
#[frb]
pub async fn get_reading_stats_by_days_with_fill(days: i32) -> Result<Vec<ReadingStats>, AppError> {
    async_storage!(|pool| StatsRepository::find_by_days_with_fill(pool, days))
}
