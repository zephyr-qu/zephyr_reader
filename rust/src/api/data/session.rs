//! 阅读会话 API
//!
//! 提供阅读会话的记录、查询和删除功能。

use chrono::NaiveDate;
use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::SessionRepository;

pub use crate::storage::models::ReadingSession;

/// 获取书籍的阅读会话列表
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `limit` - 返回数量限制
///
/// # 返回
/// 该书籍的阅读会话列表
#[frb]
pub async fn list_sessions_by_book(
    book_id: String,
    limit: i32,
) -> Result<Vec<ReadingSession>, AppError> {
    tracing::debug!("[session] list_sessions_by_book: book_id={}", book_id);
    async_storage!(|pool| SessionRepository::find_by_book(pool, &book_id, limit as i64))
}

/// 根据日期范围获取阅读会话列表
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `start_date` - 开始日期 (格式: YYYY-MM-DD)
/// * `end_date` - 结束日期 (格式: YYYY-MM-DD)
///
/// # 返回
/// 日期范围内的阅读会话列表
#[frb]
pub async fn list_sessions_by_date_range(
    book_id: String,
    start_date: String,
    end_date: String,
) -> Result<Vec<ReadingSession>, AppError> {
    // 解析日期
    let start = NaiveDate::parse_from_str(&start_date, "%Y-%m-%d")
        .map_err(|e| AppError::internal(e.to_string()))?;
    let end = NaiveDate::parse_from_str(&end_date, "%Y-%m-%d")
        .map_err(|e| AppError::internal(e.to_string()))?;
    async_storage!(|pool| SessionRepository::find_by_date_range(pool, &book_id, start, end))
}

/// 获取最近的阅读会话列表
///
/// # 参数
/// * `limit` - 返回数量限制
///
/// # 返回
/// 按时间倒序排列的最近阅读会话列表
#[frb]
pub async fn list_sessions_by_recent(limit: i32) -> Result<Vec<ReadingSession>, AppError> {
    async_storage!(|pool| SessionRepository::find_by_recent(pool, limit as i64))
}

/// 创建阅读会话（自动生成 UUID）
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
/// * `start_char_offset` - 起始字符偏移
/// * `end_char_offset` - 结束字符偏移
/// * `started_at` - 阅读开始时间（Unix 时间戳秒）
///
/// # 返回
/// 创建完成的阅读会话对象
#[frb]
pub async fn create_session(
    book_id: String,
    chapter_index: i32,
    start_char_offset: i32,
    end_char_offset: i32,
    started_at: i64,
) -> Result<ReadingSession, AppError> {
    tracing::info!("[session] create_session: book_id={}, chapter_index={}", book_id, chapter_index);
    let started = chrono::DateTime::from_timestamp(started_at, 0)
        .ok_or_else(|| AppError::internal("invalid started_at timestamp".to_string()))?;
    let session = ReadingSession::new(
        &book_id,
        chapter_index  as i64,
        start_char_offset as i64,
        end_char_offset as i64,
        started,
    );
    async_storage!(|pool| SessionRepository::save(pool, &session))
}

/// 新增或更新阅读会话记录(upsert)
#[frb]
pub async fn upsert_session(session: ReadingSession) -> Result<ReadingSession, AppError> {
    tracing::debug!("[session] upsert_session: book_id={}", session.book_id);
    async_storage!(|pool| SessionRepository::save(pool, &session))
}
/// 清除书籍的所有阅读会话
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_sessions_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| SessionRepository::delete_by_book(pool, &book_id))
}
