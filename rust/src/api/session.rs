//! 阅读会话管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::sessions::models::ReadingSession;
use crate::domain::sessions::service;

/// 获取书籍的所有阅读会话
#[frb]
pub async fn list_sessions_by_book(
    book_id: String,
    limit: i32,
) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_book: book_id={}", book_id);
    service::list_sessions_by_book(&book_id, limit as i64).await
}

/// 按日期范围查询阅读会话
#[frb]
pub async fn list_sessions_by_date_range(
    book_id: String,
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_date_range: book_id={}", book_id);
    service::list_sessions_by_date_range(&book_id, &start_date, &end_date).await
}

/// 获取最近的阅读会话
#[frb]
pub async fn list_sessions_by_recent(limit: i32) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_recent");
    service::list_sessions_by_recent(limit as i64).await
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
    tracing::info!("[session] create_session: book_id={}, chapter_index={}", book_id, chapter_index);
    service::create_session(
        &book_id,
        chapter_index as i64,
        start_char_offset as i64,
        end_char_offset as i64,
        started_at,
    ).await
}

/// 新增或更新会话
#[frb]
pub async fn upsert_session(session: ReadingSession) -> Result<ReadingSession, AppError> {
    tracing::debug!("[session] upsert_session: book_id={}", session.book_id);
    service::upsert_session(session).await
}

/// 清空书籍的所有会话
#[frb]
pub async fn clear_sessions_by_book(book_id: String) -> Result<(), AppError> {
    tracing::debug!("[session] clear_sessions_by_book: book_id={}", book_id);
    service::clear_sessions_by_book(&book_id).await
}
