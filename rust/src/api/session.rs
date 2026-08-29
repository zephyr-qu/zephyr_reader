//! 阅读会话管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;
use crate::domain::sessions::session_repo::SessionRepository;
use crate::infra::manager::storage_pool;
use chrono::DateTime;
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
    started_at: i64,
    duration_seconds: i64,
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
        started,
        duration_seconds.max(0),
    );
    let pool = storage_pool()?;
    SessionRepository::save(&pool, &session).await?;
    Ok(session)
}

/// 清空书籍的所有会话
#[frb]
pub async fn delete_sessions_by_book(book_id: String) -> Result<(), AppError> {
    tracing::debug!("[session] delete_sessions_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    SessionRepository::delete_by_book(&pool, &book_id).await
}
