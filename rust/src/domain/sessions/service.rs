//! 阅读会话业务逻辑
//!
//! 提供阅读会话的 CRUD 操作和日期范围查询。
//! 数据访问委托给 session_repo。

use chrono::{DateTime, NaiveDate};

use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;
use crate::domain::sessions::session_repo::SessionRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍的所有阅读会话
pub async fn list_sessions_by_book(
    book_id: &str,
    limit: i64,
) -> Result<Vec<ReadingSession>, AppError> {
    let pool = storage_pool()?;
    SessionRepository::find_by_book(&pool, book_id, limit).await
}

/// 按日期范围查询阅读会话
pub async fn list_sessions_by_date_range(
    book_id: &str,
    start_date: &str,
    end_date: &str,
) -> Result<Vec<ReadingSession>, AppError> {
    let start = NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
        .map_err(|e| AppError::InternalError { reason: e.to_string() })?;
    let end = NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
        .map_err(|e| AppError::InternalError { reason: e.to_string() })?;
    let pool = storage_pool()?;
    SessionRepository::find_by_date_range(&pool, book_id, start, end).await
}

/// 获取最近的阅读会话
pub async fn list_sessions_by_recent(limit: i64) -> Result<Vec<ReadingSession>, AppError> {
    let pool = storage_pool()?;
    SessionRepository::find_by_recent(&pool, limit).await
}

/// 创建新阅读会话
pub async fn create_session(
    book_id: &str,
    chapter_index: i64,
    start_char_offset: i64,
    end_char_offset: i64,
    started_at: i64,
) -> Result<ReadingSession, AppError> {
    let started = DateTime::from_timestamp(started_at, 0)
        .ok_or_else(|| AppError::InternalError { reason: "invalid started_at timestamp".to_string() })?;
    let session = ReadingSession::new(book_id, chapter_index, start_char_offset, end_char_offset, started);
    let pool = storage_pool()?;
    SessionRepository::save(&pool, &session).await
}

/// 新增或更新会话
pub async fn upsert_session(session: ReadingSession) -> Result<ReadingSession, AppError> {
    let pool = storage_pool()?;
    SessionRepository::save(&pool, &session).await
}

/// 清空书籍的所有会话
pub async fn clear_sessions_by_book(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    SessionRepository::delete_by_book(&pool, book_id).await
}

/// 获取书籍的会话数量
pub async fn count_sessions_by_book(book_id: &str) -> Result<i32, AppError> {
    let pool = storage_pool()?;
    SessionRepository::count_by_book(&pool, book_id).await
}
