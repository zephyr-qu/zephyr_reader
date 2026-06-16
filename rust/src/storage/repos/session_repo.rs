use crate::domain::AppError;
use chrono::NaiveDate;
use sqlx::SqlitePool;

use super::super::models::*;

const SQL_UPSERT_SESSION: &str = "\
INSERT INTO reading_sessions (id, book_id, chapter_index, start_char_offset, end_char_offset, started_at, ended_at, duration_seconds) \
VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8) \
ON CONFLICT(id) DO UPDATE SET \
book_id = excluded.book_id, \
chapter_index = excluded.chapter_index, \
start_char_offset = excluded.start_char_offset, \
end_char_offset = excluded.end_char_offset, \
started_at = excluded.started_at, \
ended_at = excluded.ended_at, \
duration_seconds = excluded.duration_seconds";

/// 阅读会话仓储 — 管理阅读会话记录
pub struct SessionRepository;

impl SessionRepository {
    /// 记录阅读会话
    pub async fn save(pool: &SqlitePool, session: &ReadingSession) -> Result<ReadingSession, AppError> { sqlx::query(SQL_UPSERT_SESSION)
        .bind(&session.id)
        .bind(&session.book_id)
        .bind(session.chapter_index)
        .bind(session.start_char_offset)
        .bind(session.end_char_offset)
        .bind(session.started_at)
        .bind(session.ended_at)
        .bind(session.duration_seconds)
        .execute(pool)
        .await?;
    Ok(session.clone()) }

    /// 获取指定书籍的最近会话
    pub async fn find_by_book(pool: &SqlitePool,
    book_id: &str,
    limit: i64,) -> Result<Vec<ReadingSession>, AppError> { Ok(sqlx::query_as::<_, ReadingSession>(
        "SELECT * FROM reading_sessions WHERE book_id = ? ORDER BY started_at DESC LIMIT ?",
    )
    .bind(book_id)
    .bind(limit)
    .fetch_all(pool)
    .await?) }

    /// 获取指定书籍的会话数量
    pub async fn count_by_book(pool: &SqlitePool, book_id: &str) -> Result<i32, AppError> { let count: i32 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM reading_sessions WHERE book_id = ?",
    )
    .bind(book_id)
    .fetch_one(pool)
    .await?;
    Ok(count) }

    /// 按日期范围获取会话（闭区间 [start_date, end_date]）
    ///
    /// 参数改为强类型 NaiveDate，避免调用方传入非法字符串格式
    pub async fn find_by_date_range(pool: &SqlitePool,
    book_id: &str,
    start_date: NaiveDate,
    end_date: NaiveDate,) -> Result<Vec<ReadingSession>, AppError> { let start_ts = start_date
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc()
        .timestamp();
    let end_ts = end_date.and_hms_opt(0, 0, 0).unwrap().and_utc().timestamp() + 86400;
    
    Ok(sqlx::query_as::<_, ReadingSession>(
        "SELECT * FROM reading_sessions \
         WHERE book_id = ? AND started_at >= ? AND started_at < ? \
         ORDER BY started_at DESC",
    )
    .bind(book_id)
    .bind(start_ts)
    .bind(end_ts)
    .fetch_all(pool)
    .await?) }

    /// 获取全局最近会话
    pub async fn find_by_recent(pool: &SqlitePool, limit: i64) -> Result<Vec<ReadingSession>, AppError> { Ok(sqlx::query_as::<_, ReadingSession>(
        "SELECT * FROM reading_sessions ORDER BY started_at DESC LIMIT ?",
    )
    .bind(limit)
    .fetch_all(pool)
    .await?) }

    /// 删除指定书籍的所有会话
    pub async fn delete_by_book(pool: &SqlitePool, book_id: &str) -> Result<(), AppError> { sqlx::query("DELETE FROM reading_sessions WHERE book_id = ?")
        .bind(book_id)
        .execute(pool)
        .await?;
    Ok(()) }
}

