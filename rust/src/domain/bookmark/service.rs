//! 书签业务逻辑
//!
//! 提供书签的 CRUD 操作和批量导入功能。
//! 数据访问委托给 bookmark_repo。


use crate::common::AppError;
use crate::domain::bookmark::bookmark_repo::BookmarkRepository;
use crate::domain::bookmark::models::Bookmark;
use crate::infra::manager::storage_pool;

/// 获取书籍的所有书签
pub async fn list_bookmarks_by_book(book_id: &str) -> Result<Vec<Bookmark>, AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::find_by_book(&pool, book_id).await
}

/// 创建书签
pub async fn create_bookmark(
    book_id: &str,
    chapter_index: i64,
    char_offset: i64,
    title: &str,
) -> Result<Bookmark, AppError> {
    let bookmark = Bookmark::new(book_id, chapter_index, None, char_offset, title);
    let pool = storage_pool()?;
    BookmarkRepository::save(&pool, &bookmark).await
}

/// 新增或更新书签
pub async fn upsert_bookmark(bookmark: Bookmark) -> Result<Bookmark, AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::save(&pool, &bookmark).await
}

/// 删除书签
pub async fn delete_bookmark(bookmark_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_id(&pool, bookmark_id).await
}

/// 批量删除书签
pub async fn delete_bookmarks(bookmark_ids: &[String]) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_ids(&pool, bookmark_ids).await
}

/// 根据 ID 获取书签
pub async fn get_bookmark(bookmark_id: &str) -> Result<Option<Bookmark>, AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::find_by_id(&pool, bookmark_id).await
}

/// 清空书籍的所有书签
pub async fn clear_bookmarks_by_book(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_book(&pool, book_id).await
}

/// 批量导入书签
pub async fn import_bookmarks(bookmarks: &[Bookmark]) -> Result<(), AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::import_bookmarks(&pool, bookmarks).await
}

/// 获取书签数量
pub async fn count_bookmarks_by_book(book_id: &str) -> Result<i32, AppError> {
    let pool = storage_pool()?;
    BookmarkRepository::count_by_book(&pool, book_id).await
}
