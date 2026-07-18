//! 书签管理 — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::bookmark::bookmark_repo::BookmarkRepository;
use crate::domain::bookmark::models::Bookmark;
use crate::infra::manager::storage_pool;
/// 获取书籍的所有书签列表
#[frb]
pub async fn list_bookmarks_by_book(book_id: String) -> Result<Vec<Bookmark>, AppError> {
    tracing::debug!("[bookmark] list_bookmarks_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    BookmarkRepository::find_by_book(&pool, &book_id).await
}

/// 创建书签(自动生成 UUID 并写入 DB,返回完整的 Bookmark 对象)
#[frb]
pub async fn create_bookmark(
    book_id: String,
    chapter_index: i32,
    char_offset: i32,
    title: String,
) -> Result<Bookmark, AppError> {
    tracing::info!(
        "[bookmark] create_bookmark: book_id={}, title={}",
        book_id,
        title
    );
    let bookmark = Bookmark::new(
        &book_id,
        chapter_index as i64,
        None,
        char_offset as i64,
        &title,
    );
    let pool = storage_pool()?;
    BookmarkRepository::save(&pool, &bookmark).await
}

/// 新增或更新已有书签(用于从外部导入已有 ID 的书签)
#[frb]
pub async fn upsert_bookmark(bookmark: Bookmark) -> Result<Bookmark, AppError> {
    tracing::info!("[bookmark] upsert_bookmark: id={}", bookmark.id);
    let pool = storage_pool()?;
    BookmarkRepository::save(&pool, &bookmark).await
}

/// 删除书签
#[frb]
pub async fn delete_bookmark(bookmark_id: String) -> Result<(), AppError> {
    tracing::info!("[bookmark] delete_bookmark: bookmark_id={}", bookmark_id);
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_id(&pool, &bookmark_id).await
}

/// 批量删除书签
#[frb]
pub async fn delete_bookmarks(bookmark_ids: Vec<String>) -> Result<(), AppError> {
    tracing::info!("[bookmark] delete_bookmarks: count={}", bookmark_ids.len());
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_ids(&pool, &bookmark_ids).await
}

/// 根据 ID 获取书签
#[frb]
pub async fn get_bookmark(bookmark_id: String) -> Result<Option<Bookmark>, AppError> {
    tracing::debug!("[bookmark] get_bookmark: bookmark_id={}", bookmark_id);
    let pool = storage_pool()?;
    BookmarkRepository::find_by_id(&pool, &bookmark_id).await
}

/// 清除书籍的所有书签
#[frb]
pub async fn delete_bookmarks_by_book(book_id: String) -> Result<(), AppError> {
    tracing::debug!("[bookmark] delete_bookmarks_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    BookmarkRepository::delete_by_book(&pool, &book_id).await
}

/// 批量导入书签
#[frb]
pub async fn import_bookmarks(bookmarks: Vec<Bookmark>) -> Result<(), AppError> {
    tracing::info!("[bookmark] import_bookmarks: count={}", bookmarks.len());
    let pool = storage_pool()?;
    BookmarkRepository::import_bookmarks(&pool, &bookmarks).await
}

/// 获取书签数量统计
#[frb]
pub async fn count_bookmarks_by_book(book_id: String) -> Result<i32, AppError> {
    tracing::debug!("[bookmark] count_bookmarks_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    BookmarkRepository::count_by_book(&pool, &book_id).await
}
