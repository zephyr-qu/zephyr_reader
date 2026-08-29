use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：阅读统计仓储，管理全局统计与每日阅读统计
//
// 公有类型/函数：
//   - StatsRepository — 阅读统计仓储结构体
//   - find_by_global() — 全局统计汇总
//   - find_by_days_with_fill() — 最近 N 天含补零（每日直读 reading_sessions）
//
// 私有函数：
//   - calculate_consecutive_reading_days() — 连续阅读天数
//
// 真相源：`reading_sessions` 是唯一事实来源；所有聚合（全局/每日/连续
// 天数）均由它实时计算，不维护 `reading_stats` 中间缓存表。
// ============================================================

use std::collections::HashSet;

use crate::domain::AppError;
use crate::domain::stats::models::{DailyReadingStats, GlobalStats};
use chrono::Utc;
use sqlx::SqlitePool;

/// 计算连续阅读天数（从今日起向前回溯，基于 reading_sessions 活跃日）
async fn calculate_consecutive_reading_days(pool: &SqlitePool) -> Result<i64, AppError> {
    let rows: Vec<String> = sqlx::query_scalar(
        "SELECT DISTINCT date(started_at) AS d FROM reading_sessions \
     WHERE duration_seconds > 0 \
       AND d >= date('now', '-365 days') \
     ORDER BY d DESC",
    )
    .fetch_all(pool)
    .await?;

    if rows.is_empty() {
        return Ok(0);
    }

    let date_set: HashSet<&str> = rows.iter().map(|s| s.as_str()).collect();
    let mut days = 0;
    let mut current_date = Utc::now().date_naive();

    loop {
        let date_str = current_date.to_string();
        if date_set.contains(date_str.as_str()) {
            days += 1;
            match current_date.pred_opt() {
                Some(prev) => current_date = prev,
                None => break,
            }
        } else {
            break;
        }
    }
    Ok(days)
}

/// 阅读统计仓储 — 管理全局统计与每日统计（均为 reading_sessions 实时聚合）
#[frb(opaque)]
pub struct StatsRepository;

impl StatsRepository {
    /// 获取全局统计汇总
    pub async fn find_by_global(pool: &SqlitePool) -> Result<GlobalStats, AppError> {
        let today_start = Utc::now()
            .date_naive()
            .and_hms_opt(0, 0, 0)
            .unwrap()
            .and_utc()
            .timestamp();
        let today_end = today_start + 86400;
        let mut stats: GlobalStats = sqlx::query_as(
        "SELECT \
            COALESCE((SELECT SUM(duration_seconds) FROM reading_sessions), 0) AS total_reading_time_seconds, \
            (SELECT COUNT(DISTINCT book_id) FROM reading_sessions) AS books_read_count, \
            (SELECT COUNT(*) FROM reading_progress WHERE is_completed != 0) AS books_completed_count, \
            COALESCE((SELECT SUM(duration_seconds) FROM reading_sessions WHERE started_at >= ?1 AND started_at < ?2), 0) AS today_reading_time_seconds, \
            (SELECT COUNT(*) FROM books) AS total_books_count, \
            (SELECT COUNT(*) FROM notes) AS total_notes_count, \
            (SELECT COUNT(*) FROM bookmarks) AS total_bookmarks_count",
        )
        .bind(today_start)
        .bind(today_end)
        .fetch_one(pool)
        .await?;

        stats.consecutive_reading_days = calculate_consecutive_reading_days(pool).await?;

        Ok(stats)
    }

    /// 获取最近 N 天的每日聚合（按本地日期），缺失的日期补 0。
    ///
    /// 直接按 `reading_sessions.started_at` 分组（unixepoch localtime），
    /// 不再依赖 `reading_stats` 缓存表。
    pub async fn find_by_days_with_fill(
        pool: &SqlitePool,
        days: i32,
    ) -> Result<Vec<DailyReadingStats>, AppError> {
        let today = Utc::now().date_naive();
        let start_date = today - chrono::Duration::days((days - 1) as i64);

        let start = start_date.to_string();
        let end = today.to_string();

        // 按本地日期聚合多本书（趋势/热力图按天显示，忽略书粒度）
        use std::collections::HashMap;
        let stats_list: Vec<DailyReadingStats> = sqlx::query_as(
            "SELECT \
                date(started_at) AS date, \
                SUM(duration_seconds) AS reading_time_seconds, \
                COUNT(*) AS session_count, \
                MAX(id) AS last_session_id \
             FROM reading_sessions \
             WHERE date(started_at) >= ?1 \
               AND date(started_at) <= ?2 \
             GROUP BY date(started_at) \
             ORDER BY date",
        )
        .bind(&start)
        .bind(&end)
        .fetch_all(pool)
        .await?;

        let mut stats_map: HashMap<String, DailyReadingStats> =
            stats_list.into_iter().map(|s| (s.date.clone(), s)).collect();

        // 补全缺失的日期
        let mut result = Vec::with_capacity(days as usize);
        for i in 0..days {
            let date = today - chrono::Duration::days((days - 1 - i) as i64);
            let date_str = date.to_string();

            match stats_map.remove(&date_str) {
                Some(stats) => result.push(stats),
                None => {
                    // 创建空的统计数据
                    result.push(DailyReadingStats {
                        date: date_str,
                        reading_time_seconds: 0,
                        session_count: 0,
                        last_session_id: None,
                    });
                }
            }
        }
        Ok(result)
    }
}