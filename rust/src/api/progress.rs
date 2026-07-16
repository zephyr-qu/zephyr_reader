//! 阅读进度管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::progress::models::{BookWithProgress, ReadingProgress};
use crate::domain::progress::progress_repo::ProgressRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍阅读进度
#[frb]
pub async fn get_progress(book_id: String) -> Result<Option<ReadingProgress>, AppError> {
    let pool = storage_pool()?;
    ProgressRepository::find_by_book(&pool, &book_id).await
}

/// 新增或更新阅读进度
#[frb]
pub async fn upsert_progress(progress: ReadingProgress) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ProgressRepository::save(&pool, &progress).await
}

/// 获取所有书籍的阅读进度
#[frb]
pub async fn list_all_progresses() -> Result<Vec<BookWithProgress>, AppError> {
    tracing::debug!("[progress] list_all_progresses");
    let pool = storage_pool()?;
    ProgressRepository::list_all_with_progress(&pool).await
}

/// 清除书籍阅读进度
#[frb]
pub async fn delete_progress(book_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ProgressRepository::clear_by_book(&pool, &book_id).await
}


