//! 章节管理业务逻辑
//!
//! 提供章节的查询和批量保存功能。
//! 数据访问委托给 ChapterRepository。

use crate::common::AppError;
use crate::domain::chapter::Chapter;
use crate::domain::chapter::chapter_repo::ChapterRepository;
use crate::infra::manager::storage_pool;

/// 获取书籍的所有章节列表
pub async fn list_chapters_by_book(book_id: &str) -> Result<Vec<Chapter>, AppError> {
    let pool = storage_pool()?;
    ChapterRepository::find_by_book(&pool, book_id).await
}

/// 新增或更新章节列表
pub async fn upsert_chapters(book_id: &str, chapters: &[Chapter]) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ChapterRepository::save(&pool, book_id, chapters).await
}

/// 清除书籍的所有章节
pub async fn clear_chapters_by_book(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    ChapterRepository::delete_by_book(&pool, book_id).await
}

/// 根据章节索引获取章节
pub async fn get_chapter_by_index(book_id: &str, chapter_index: i32) -> Result<Option<Chapter>, AppError> {
    let pool = storage_pool()?;
    ChapterRepository::find_by_index(&pool, book_id, chapter_index).await
}
