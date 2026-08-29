use flutter_rust_bridge::frb;
// ============================================================
// 文件作用：阅读统计仓储，管理每日阅读统计和全局统计
//
// 公有类型/函数：
//   - StatsRepository — 阅读统计仓储结构体
//   - find_by_global() — 全局统计汇总
//   - aggregate_session() — 会话结束时的每日统计增量聚合（唯一写入路径）
//   - find_by_days_with_fill() — 最近 N 天含补零
//
// 私有函数：
//   - calculate_consecutive_reading_days() — 连续阅读天数
// ============================================================

use std::collections::HashSet;

use crate::domain::AppError;
use crate::domain::stats::models::{GlobalStats, ReadingStats};
use chrono::Utc;
use sqlx::SqlitePool;

/// 不变量：`reading_stats` 仅在阅读会话结束时由 `reading_sessions` 增量聚合更新，
/// 不允许直接写入。`last_session_id` 记录最后一次聚合的会话 ID，用于排查聚合遗漏/重复。
/// 如需新增写入入口，必须确保此不变量不被破坏。
const SQL_UPSERT_READING_STATS: &str = "\
INSERT INTO reading_stats (book_id, date, reading_time_seconds, session_count, last_session_id) \
VALUES (?1, ?2, ?3, ?4, ?5) \
ON CONFLICT(book_id, date) DO UPDATE SET \
reading_time_seconds = excluded.reading_time_seconds, \
session_count = excluded.session_count, \
last_session_id = excluded.last_session_id";

/// 计算连续阅读天数（从今日起向前回溯）
async fn calculate_consecutive_reading_days(pool: &SqlitePool) -> Result<i64, AppError> {
    let rows: Vec<String> = sqlx::query_scalar(
        "SELECT DISTINCT date FROM reading_stats \
     WHERE reading_time_seconds > 0 \
       AND date >= date('now', '-365 days') \
     ORDER BY date DESC",
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

/// 阅读统计仓储 — 管理每日阅读统计和全局统计
#[frb(opaque)]
pub struct StatsRepository;

impl StatsRepository {
    /// 获取全局统计汇总
    /// 将 7 次独立查询合并为 1 次聚合查询 + 1 次连续天数查询
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

    /// 聚合单个阅读会话到每日统计（阅读会话结束时调用）
    ///
    /// 不变量：`reading_stats` 仅在阅读会话结束时由 `reading_sessions` 增量聚合更新。
    /// 按 (book_id, date) 读取现有累计值并叠加本次会话的时长与阅读字符数。
    pub async fn aggregate_session(
        pool: &SqlitePool,
        session: &crate::domain::sessions::models::ReadingSession,
    ) -> Result<(), AppError> {
        let date = session.started_at.date_naive().to_string();

        let existing: Option<ReadingStats> = sqlx::query_as::<_, ReadingStats>(
            "SELECT * FROM reading_stats WHERE book_id = ? AND date = ?",
        )
        .bind(&session.book_id)
        .bind(&date)
        .fetch_optional(pool)
        .await?;

        let stats = match existing {
            Some(prev) => ReadingStats {
                book_id: prev.book_id,
                date: prev.date,
                reading_time_seconds: prev.reading_time_seconds + session.duration_seconds,
                session_count: prev.session_count + 1,
                last_session_id: Some(session.id.clone()),
            },
            None => ReadingStats {
                book_id: session.book_id.clone(),
                date,
                reading_time_seconds: session.duration_seconds,
                session_count: 1,
                last_session_id: Some(session.id.clone()),
            },
        };

        sqlx::query(SQL_UPSERT_READING_STATS)
            .bind(&stats.book_id)
            .bind(&stats.date)
            .bind(stats.reading_time_seconds)
            .bind(stats.session_count)
            .bind(&stats.last_session_id)
            .execute(pool)
            .await?;
        Ok(())
    }

    /// 获取最近 N 天的统计数据（包含今天），缺失的日期补 0
    ///
    /// 这个方法会确保返回整整 `days` 天的数据，如果某天没有阅读记录，
    /// 会补全一个阅读时间为 0 的记录。
    pub async fn find_by_days_with_fill(
        pool: &SqlitePool,
        days: i32,
    ) -> Result<Vec<ReadingStats>, AppError> {
        let today = Utc::now().date_naive();
        let start_date = today - chrono::Duration::days((days - 1) as i64);

        let start = start_date.to_string();
        let end = today.to_string();

        // 查询并按日期聚合多本书（趋势/热力图按天显示，忽略书粒度）
        use std::collections::HashMap;
        let stats_list: Vec<ReadingStats> = sqlx::query_as(
            "SELECT \
                ?2 AS book_id, \
                date, \
                SUM(reading_time_seconds) AS reading_time_seconds, \
                SUM(session_count) AS session_count, \
                MAX(last_session_id) AS last_session_id \
             FROM reading_stats \
             WHERE date >= ?1 AND date <= ?2 \
             GROUP BY date \
             ORDER BY date",
        )
        .bind(&start)
        .bind(&end)
        .fetch_all(pool)
        .await?;

        let mut stats_map: HashMap<String, ReadingStats> =
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
                    result.push(ReadingStats {
                        book_id: "".to_string(),
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
