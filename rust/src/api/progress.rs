//! 阅读进度管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::progress::models::ReadingProgress;
use crate::domain::progress::progress_repo::ProgressRepository;
use crate::infra::manager::storage_pool;

/// 新增或更新阅读进度
#[frb]
pub async fn upsert_progress(progress: ReadingProgress) -> Result<(), AppError> {
    tracing::debug!("[progress] upsert_progress: book_id={}", progress.book_id);
    let pool = storage_pool()?;
    ProgressRepository::save(&pool, &progress).await
}
