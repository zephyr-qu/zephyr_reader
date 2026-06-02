//! 章节管理 API
//!
//! 提供章节的保存、查询和删除功能。
//!
//! @dart_call - 被 Dart 侧 ChapterService 调用

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::ChapterRepository;

pub use crate::storage::models::Chapter;

/// 获取书籍的所有章节列表
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 该书籍的所有章节列表
#[frb]
pub async fn list_chapters_by_book(book_id: String) -> Result<Vec<Chapter>, AppError> {
    async_storage!(|pool| ChapterRepository::find_by_book(pool, &book_id))
}

/// 新增或更新章节列表(upsert)
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapters` - 章节列表
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn upsert_chapters(book_id: String, chapters: Vec<Chapter>) -> Result<(), AppError> {
    async_storage!(|pool| ChapterRepository::save(pool, &book_id, &chapters))
}

/// 清除书籍的所有章节
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_chapters_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| ChapterRepository::delete_by_book(pool, &book_id))
}

/// 根据章节索引获取章节
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
///
/// # 返回
/// 存在则返回 Some(Chapter), 否则返回 None
#[frb]
pub async fn get_chapter_by_index(
    book_id: String,
    chapter_index: i32,
) -> Result<Option<Chapter>, AppError> {
    async_storage!(|pool| ChapterRepository::find_by_index(pool, &book_id, chapter_index))
}
