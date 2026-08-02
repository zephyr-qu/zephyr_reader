//! 阅读会话管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;
use crate::domain::sessions::session_repo::SessionRepository;
use crate::domain::stats::stats_repo::StatsRepository;
use crate::infra::manager::storage_pool;
use chrono::{DateTime, NaiveDate};
/// 获取书籍的所有阅读会话
#[frb]
pub async fn list_sessions_by_book(
    book_id: String,
    limit: i32,
) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    SessionRepository::find_by_book(&pool, &book_id, limit as i64).await
}

/// 按日期范围查询阅读会话
#[frb]
pub async fn list_sessions_by_date_range(
    book_id: String,
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_date_range: book_id={}", book_id);
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
    SessionRepository::find_by_date_range(&pool, &book_id, start, end).await
}

/// 获取最近的阅读会话
#[frb]
pub async fn list_sessions_by_recent(limit: i32) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_recent");
    let pool = storage_pool()?;
    SessionRepository::find_by_recent(&pool, limit as i64).await
}

/// 创建新阅读会话
#[frb]
pub async fn create_session(
    book_id: String,
    chapter_index: i32,
    start_char_offset: i32,
    end_char_offset: i32,
    started_at: i64,
) -> Result<ReadingSession, AppError> {
    tracing::info!(
        "[session] create_session: book_id={}, chapter_index={}",
        book_id,
        chapter_index
    );
    let started =
        DateTime::from_timestamp(started_at, 0).ok_or_else(|| AppError::InternalError {
            reason: "invalid started_at timestamp".to_string(),
        })?;
    let session = ReadingSession::new(
        &book_id,
        chapter_index as i64,
        start_char_offset as i64,
        end_char_offset as i64,
        started,
    );
    let pool = storage_pool()?;
    SessionRepository::save(&pool, &session).await?;
    // 不变量：reading_stats 仅在会话结束时由 reading_sessions 增量聚合更新。
    StatsRepository::aggregate_session(&pool, &session).await?;
    Ok(session)
}

/// 新增或更新会话
#[frb]
pub async fn upsert_session(session: ReadingSession) -> Result<ReadingSession, AppError> {
    tracing::debug!("[session] upsert_session: book_id={}", session.book_id);
    let pool = storage_pool()?;
    SessionRepository::save(&pool, &session).await
}

/// 清空书籍的所有会话
#[frb]
pub async fn delete_sessions_by_book(book_id: String) -> Result<(), AppError> {
    tracing::debug!("[session] delete_sessions_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    SessionRepository::delete_by_book(&pool, &book_id).await
}
