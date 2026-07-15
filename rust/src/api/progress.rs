//! 阅读进度管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::progress::models::{BookWithProgress, ReadingProgress};
use crate::domain::progress::service;

/// 获取书籍阅读进度
#[frb]
pub async fn get_progress(book_id: String) -> Result<Option<ReadingProgress>, AppError> {
    service::get_progress(&book_id).await
}

/// 新增或更新阅读进度
#[frb]
pub async fn upsert_progress(progress: ReadingProgress) -> Result<(), AppError> {
    service::upsert_progress(&progress).await
}

/// 获取所有书籍的阅读进度
#[frb]
pub async fn list_all_progresses() -> Result<Vec<BookWithProgress>, AppError> {
    tracing::debug!("[progress] list_all_progresses");
    service::list_all_progresses().await
}

/// 清除书籍阅读进度
#[frb]
pub async fn clear_progress(book_id: String) -> Result<(), AppError> {
    service::clear_progress(&book_id).await
}
