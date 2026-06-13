use std::collections::HashSet;

use crate::domain::AppError;
use chrono::{NaiveDate, Utc};
use sqlx::SqlitePool;

use super::super::models::*;

/// 不变量：`reading_stats` 仅在阅读会话结束时由 `reading_sessions` 增量聚合更新，
/// 不允许直接写入。`last_session_id` 记录最后一次聚合的会话 ID，用于排查聚合遗漏/重复。
/// 如需新增写入入口，必须确保此不变量不被破坏。
const SQL_UPSERT_READING_STATS: &str = "\
INSERT INTO reading_stats (book_id, date, reading_time_seconds, characters_read, session_count, last_session_id) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6) \
ON CONFLICT(book_id, date) DO UPDATE SET \
reading_time_seconds = excluded.reading_time_seconds, \
characters_read = excluded.characters_read, \
session_count = excluded.session_count, \
last_session_id = excluded.last_session_id";

/// 计算连续阅读天数（从今日起向前回溯）
async fn calculate_consecutive_reading_days(pool: &SqlitePool) -> Result<i64, AppError> { let rows: Vec<String> = sqlx::query_scalar(
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
Ok(days) }

/// 阅读统计仓储 — 管理每日阅读统计和全局统计
pub struct StatsRepository;

impl StatsRepository {
    /// 获取今日统计
    pub async fn find_by_today(pool: &SqlitePool) -> Result<Vec<ReadingStats>, AppError> { let today = Utc::now().date_naive().to_string();
    Ok(
        sqlx::query_as::<_, ReadingStats>("SELECT * FROM reading_stats WHERE date = ?")
            .bind(&today)
            .fetch_all(pool)
            .await?,
    ) }

    /// 按日期范围获取统计（参数改为强类型 NaiveDate）
    pub async fn find_by_range(pool: &SqlitePool,
    start_date: NaiveDate,
    end_date: NaiveDate,) -> Result<Vec<ReadingStats>, AppError> { let start = start_date.to_string();
    let end = end_date.to_string();
    Ok(sqlx::query_as::<_, ReadingStats>(
        "SELECT * FROM reading_stats WHERE date >= ? AND date <= ? ORDER BY date",
    )
    .bind(&start)
    .bind(&end)
    .fetch_all(pool)
    .await?) }

    /// 获取全局统计汇总
    /// 将 7 次独立查询合并为 1 次聚合查询 + 1 次连续天数查询
    pub async fn find_by_global(pool: &SqlitePool) -> Result<GlobalStats, AppError> { let today_start = Utc::now()
        .date_naive()
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc()
        .timestamp();
    let today_end = today_start + 86400;
    let agg: AggregatedStats = sqlx::query_as(
        "SELECT \
            COALESCE((SELECT SUM(duration_seconds) FROM reading_sessions), 0) AS total_reading_time_seconds, \
            COALESCE((SELECT SUM(CASE WHEN end_char_offset > start_char_offset THEN end_char_offset - start_char_offset ELSE 0 END) FROM reading_sessions), 0) AS total_characters_read, \
            (SELECT COUNT(DISTINCT book_id) FROM reading_sessions) AS books_read_count, \
            (SELECT COUNT(*) FROM reading_progress WHERE is_completed != 0) AS books_completed_count, \
            (SELECT COUNT(*) FROM books) AS total_books_count, \
            (SELECT COUNT(*) FROM notes) AS total_notes_count, \
            (SELECT COUNT(*) FROM bookmarks) AS total_bookmarks_count, \
            COALESCE((SELECT SUM(duration_seconds) FROM reading_sessions WHERE started_at >= ?1 AND started_at < ?2), 0) AS today_reading_time_seconds, \
            COALESCE((SELECT SUM(CASE WHEN end_char_offset > start_char_offset THEN end_char_offset - start_char_offset ELSE 0 END) FROM reading_sessions WHERE started_at >= ?1 AND started_at < ?2), 0) AS today_characters_read",
    )
    .bind(today_start)
    .bind(today_end)
    .fetch_one(pool)
    .await?;
    
    let average_reading_speed = if agg.total_reading_time_seconds > 0 {
        (agg.total_characters_read as f64 / agg.total_reading_time_seconds as f64 * 60.0) as f32
    } else {
        0.0
    };
    
    let consecutive_reading_days = calculate_consecutive_reading_days(pool).await?;
    Ok(GlobalStats {
        total_reading_time_seconds: agg.total_reading_time_seconds,
        total_characters_read: agg.total_characters_read,
        books_read_count: agg.books_read_count,
        books_completed_count: agg.books_completed_count,
        consecutive_reading_days,
        today_reading_time_seconds: agg.today_reading_time_seconds,
        today_characters_read: agg.today_characters_read,
        average_reading_speed,
        total_books_count: agg.total_books_count,
        total_notes_count: agg.total_notes_count,
        total_bookmarks_count: agg.total_bookmarks_count,
    }) }

    /// 更新每日统计
    pub async fn update_by_daily(pool: &SqlitePool, stats: &ReadingStats) -> Result<(), AppError> { sqlx::query(SQL_UPSERT_READING_STATS)
        .bind(&stats.book_id)
        .bind(&stats.date)
        .bind(stats.reading_time_seconds)
        .bind(stats.characters_read)
        .bind(stats.session_count)
        .bind(&stats.last_session_id)
        .execute(pool)
        .await?;
    Ok(()) }
    /// 获取最近 N 天的统计数据（包含今天）
    ///
    /// # Arguments
    /// * `days` - 天数，例如 7 表示最近 7 天（包含今天）
    ///
    /// # Returns
    /// 按日期倒序排列（最新的在前面）的统计列表
    pub async fn find_by_days(pool: &SqlitePool, days: i32) -> Result<Vec<ReadingStats>, AppError> { let today = Utc::now().date_naive();
    let start_date = today - chrono::Duration::days((days - 1) as i64);
    
    let start = start_date.to_string();
    let end = today.to_string();
    
    Ok(sqlx::query_as::<_, ReadingStats>(
        "SELECT * FROM reading_stats
         WHERE date >= ? AND date <= ?
         ORDER BY date DESC",
    )
    .bind(&start)
    .bind(&end)
    .fetch_all(pool)
    .await?) }

    /// 获取最近 N 天的统计数据（包含今天），缺失的日期补 0
    ///
    /// 这个方法会确保返回整整 `days` 天的数据，如果某天没有阅读记录，
    /// 会补全一个阅读时间为 0 的记录。
    pub async fn find_by_days_with_fill(pool: &SqlitePool, days: i32) -> Result<Vec<ReadingStats>, AppError> { let today = Utc::now().date_naive();
    let start_date = today - chrono::Duration::days((days - 1) as i64);
    
    let start = start_date.to_string();
    let end = today.to_string();
    
    // 查询已有的数据
    let mut stats_list: Vec<ReadingStats> = sqlx::query_as::<_, ReadingStats>(
        "SELECT * FROM reading_stats
         WHERE date >= ? AND date <= ?
         ORDER BY date",
    )
    .bind(&start)
    .bind(&end)
    .fetch_all(pool)
    .await?;
    
    // 将已有数据转为 HashMap 方便查找
    use std::collections::HashMap;
    let mut stats_map: HashMap<String, ReadingStats> =
        stats_list.drain(..).map(|s| (s.date.clone(), s)).collect();
    
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
                    characters_read: 0,
                    session_count: 0,
                    last_session_id: None,
                });
            }
        }
    }
    Ok(result) }
}

// #[cfg(test)]
// mod tests {
//     use super::*;
//     use crate::storage::repos::book_repo::BookRepository;
//     use crate::storage::repos::session_repo::SessionRepository;
//     use crate::storage::repos::test_utils::*;

//     #[tokio::test]
//     async fn test_upsert_daily_stats() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let today = Utc::now().date_naive().to_string();
//         let stats = ReadingStats {
//             book_id: "book1".to_string(),
//             date: today.clone(),
//             reading_time_seconds: 600,
//             characters_read: 1000,
//             session_count: 1,
//         };
//         StatsRepository::update_daily_stats(&pool, &stats).await.unwrap();
//         let merged = ReadingStats {
//             book_id: "book1".to_string(),
//             date: today.clone(),
//             reading_time_seconds: 1200,
//             characters_read: 2000,
//             session_count: 2,
//         };
//         StatsRepository::update_daily_stats(&pool, &merged).await.unwrap();
//         let range = StatsRepository::get_stats_range(&pool, &today, &today).await.unwrap();
//         assert_eq!(range.len(), 1);
//         assert_eq!(range[0].reading_time_seconds, 1200);
//     }

//     #[tokio::test]
//     async fn test_get_today_stats() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let today = Utc::now().date_naive().to_string();
//         StatsRepository::update_daily_stats(&pool, &ReadingStats {
//             book_id: "book1".to_string(), date: today.clone(),
//             reading_time_seconds: 300, characters_read: 500, session_count: 1,
//         }).await.unwrap();
//         let today_stats = StatsRepository::get_today_stats(&pool).await.unwrap();
//         assert_eq!(today_stats.len(), 1);
//         assert_eq!(today_stats[0].reading_time_seconds, 300);
//     }

//     #[tokio::test]
//     async fn test_get_stats_range() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         StatsRepository::update_daily_stats(&pool, &ReadingStats {
//             book_id: "book1".to_string(), date: "2024-01-01".to_string(),
//             reading_time_seconds: 100, characters_read: 200, session_count: 1,
//         }).await.unwrap();
//         StatsRepository::update_daily_stats(&pool, &ReadingStats {
//             book_id: "book1".to_string(), date: "2024-01-02".to_string(),
//             reading_time_seconds: 200, characters_read: 400, session_count: 1,
//         }).await.unwrap();
//         let range = StatsRepository::get_stats_range(&pool, "2024-01-01", "2024-01-02").await.unwrap();
//         assert_eq!(range.len(), 2);
//     }

//     #[tokio::test]
//     async fn test_get_global_stats() {
//         let pool = setup_test_db().await;
//         BookRepository::save(&pool, &test_book()).await.unwrap();
//         let session = test_session("book1", 0, None);
//         SessionRepository::record_session(&pool, &session).await.unwrap();
//         let global = StatsRepository::get_global_stats(&pool).await.unwrap();
//         assert_eq!(global.total_reading_time_seconds, 1800);
//         assert_eq!(global.total_characters_read, 500);
//     }
// }
