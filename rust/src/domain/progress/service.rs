//! 阅读进度业务逻辑
//!
//! 提供阅读进度的查询和更新功能。
//! 数据访问委托给 ProgressRepository。

use crate::common::AppError;
use crate::domain::progress::models::{BookWithProgress, ReadingProgress};
use crate::domain::progress::progress_repo::ProgressRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍阅读进度
pub async fn get_progress(book_id: &str) -> Result<Option<ReadingProgress>, AppError> {
    let pool = storage_pool()?;
    ProgressRepository::find_by_book(&pool, book_id).await
}

/// 新增或更新阅读进度
pub async fn upsert_progress(progress: &ReadingProgress) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ProgressRepository::save(&pool, progress).await
}

/// 获取所有书籍的阅读进度
pub async fn list_all_progresses() -> Result<Vec<BookWithProgress>, AppError> {
    let pool = storage_pool()?;
    ProgressRepository::list_all_with_progress(&pool).await
}

/// 清除书籍阅读进度
pub async fn clear_progress(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ProgressRepository::clear_by_book(&pool, book_id).await
}
