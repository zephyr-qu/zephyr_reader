//! 书签管理 API
//!
//! 提供书签的 CRUD 操作、导入、同步等功能。
//!
//! @dart_call - 被 Dart 侧 BookmarkService 调用

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::BookmarkRepository;

pub use crate::storage::models::Bookmark;

/// 获取书籍的所有书签列表
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 该书籍的所有书签列表
#[frb]
pub async fn list_bookmarks_by_book(book_id: String) -> Result<Vec<Bookmark>, AppError> {
    async_storage!(|pool| BookmarkRepository::find_by_book(pool, &book_id))
}

/// 创建书签(自动生成 UUID 并写入 DB,返回完整的 Bookmark 对象)
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
/// * `char_offset` - 字符偏移量
/// * `title` - 书签标题
///
/// # 返回
/// 创建完成的书签对象
#[frb]
pub async fn create_bookmark(
    book_id: String,
    chapter_index: i32,
    char_offset: i32,
    title: String,
) -> Result<Bookmark, AppError> {
    let bookmark = Bookmark::new(&book_id, chapter_index as i64, None, char_offset as i64, &title);
    async_storage!(|pool| BookmarkRepository::save(pool, &bookmark))
}

/// 新增或更新已有书签(用于从外部导入已有 ID 的书签)
///
/// # 参数
/// * `bookmark` - 要保存的书签对象
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn upsert_bookmark(bookmark: Bookmark) -> Result<Bookmark, AppError> {
    async_storage!(|pool| BookmarkRepository::save(pool, &bookmark))
}

/// 删除书签
///
/// # 参数
/// * `bookmark_id` - 书签 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_bookmark(bookmark_id: String) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::delete_by_id(pool, &bookmark_id))
}

/// 批量删除书签
///
/// # 参数
/// * `bookmark_ids` - 要删除的书签 ID 列表
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_bookmarks(bookmark_ids: Vec<String>) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::delete_by_ids(pool, &bookmark_ids))
}

/// 根据 ID 获取书签
///
/// # 参数
/// * `bookmark_id` - 书签 ID
///
/// # 返回
/// 存在则返回 Some(Bookmark), 否则返回 None
#[frb]
pub async fn get_bookmark(bookmark_id: String) -> Result<Option<Bookmark>, AppError> {
    async_storage!(|pool| BookmarkRepository::find_by_id(pool, &bookmark_id))
}

/// 清除书籍的所有书签
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_bookmarks_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::delete_by_book(pool, &book_id))
}

/// 批量导入书签
///
/// # 参数
/// * `bookmarks` - 要导入的书签列表
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn import_bookmarks(bookmarks: Vec<Bookmark>) -> Result<(), AppError> {
    async_storage!(|pool| BookmarkRepository::import_bookmarks(pool, &bookmarks))
}

/// 获取书签数量统计
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 该书籍的书签总数
#[frb]
pub async fn count_bookmarks_by_book(book_id: String) -> Result<i32, AppError> {
    async_storage!(|pool| BookmarkRepository::count_by_book(pool, &book_id))
}
