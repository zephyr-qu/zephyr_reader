//! 章节管理 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::chapter::Chapter;
use crate::domain::chapter::chapter_repo::ChapterRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍的所有章节列表
#[frb]
pub async fn list_chapters_by_book(book_id: String) -> Result<Vec<Chapter>, AppError> {
    tracing::debug!("[chapter] list_chapters_by_book: book_id={}", book_id);
    let pool = storage_pool()?;
    ChapterRepository::find_by_book(&pool, &book_id).await
}

/// 新增或更新章节列表
#[frb]
pub async fn upsert_chapters(book_id: String, chapters: Vec<Chapter>) -> Result<(), AppError> {
    tracing::info!(
        "[chapter] upsert_chapters: book_id={}, count={}",
        book_id,
        chapters.len()
    );
    let pool = storage_pool()?;
    ChapterRepository::save(&pool, &book_id, &chapters).await
}

/// 清除书籍的所有章节
#[frb]
pub async fn delete_chapters_by_book(book_id: String) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ChapterRepository::delete_by_book(&pool, &book_id).await
}

/// 根据章节索引获取章节
#[frb]
pub async fn get_chapter_by_index(
    book_id: String,
    chapter_index: i32,
) -> Result<Option<Chapter>, AppError> {
    tracing::debug!(
        "[chapter] get_chapter_by_index: book_id={}, chapter_index={}",
        book_id,
        chapter_index
    );
    let pool = storage_pool()?;
    ChapterRepository::find_by_index(&pool, &book_id, chapter_index).await
}
