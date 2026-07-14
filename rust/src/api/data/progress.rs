//! 阅读进度 API
//!
//! 提供阅读进度的保存、获取和清除功能。

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::ProgressRepository;

pub use crate::storage::models::BookWithProgress;
pub use crate::storage::models::ReadingProgress;

// ============================================================
// 文件作用：阅读进度 API — 进度保存、获取、清除。
//
// 公有函数：
//   - get_progress() — 根据书籍 ID 获取进度
//   - upsert_progress() — 新增或更新进度
//   - list_all_progresses() — 所有书籍的进度（批量书架用）
//   - clear_progress() — 清除阅读进度
// ============================================================

/// 根据书籍 ID 获取阅读进度
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 存在则返回 Some(ReadingProgress), 否则返回 None
#[frb]
pub async fn get_progress(book_id: String) -> Result<Option<ReadingProgress>, AppError> {
    async_storage!(|pool| ProgressRepository::find_by_book(pool, &book_id))
}

/// 新增或更新阅读进度(upsert)
///
/// # 参数
/// * `progress` - 阅读进度对象
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn upsert_progress(progress: ReadingProgress) -> Result<(), AppError> {
    async_storage!(|pool| ProgressRepository::save(pool, &progress))
}

/// 获取所有书籍的阅读进度(批量书架用)
///
/// 替代 Dart 侧 getAllBooks() + N×findByBook() 的 N+1 查询。
/// 内部执行 2 次 SQL(banks + progress),Rust 层按 book_id 匹配。
///
/// # 返回
/// 包含阅读进度的书籍列表
#[frb]
pub async fn list_all_progresses() -> Result<Vec<BookWithProgress>, AppError> {
    tracing::debug!("[progress] list_all_progresses");
    async_storage!(|pool| ProgressRepository::list_all_with_progress(pool))
}

/// 清除阅读进度
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_progress(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| ProgressRepository::clear_by_book(pool, &book_id))
}
