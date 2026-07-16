//! 章节读取 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::book::book_repo::BookRepository;
use crate::infra::manager::storage_pool;
use crate::pipeline::{chapter_ir, ReaderChapterIr};

async fn get_book_file_path(book_id: &str) -> Result<String, AppError> {
    let pool = storage_pool()?;
    let book = BookRepository::find_by_id(&pool, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound { entity: format!("book {book_id}") })?;
    Ok(book.file_path)
}

/// 获取指定章节的原始文本内容（退化备选）
#[frb]
pub async fn get_chapter(file_path: String, chapter_index: i32) -> Result<String, AppError> {
    chapter_ir::get_chapter(file_path, chapter_index).await
}

/// 获取指定章节的原始文本内容（通过 book_id）
#[frb]
pub async fn get_chapter_plain(book_id: String, chapter_index: i32) -> Result<String, AppError> {
    let file_path = get_book_file_path(&book_id).await?;
    chapter_ir::get_chapter(file_path, chapter_index).await
}

/// 加载整章 ReaderIrBlock IR
#[frb]
pub async fn get_chapter_content_ir(
    book_id: String,
    chapter_index: i32,
) -> Result<ReaderChapterIr, AppError> {
    let file_path = get_book_file_path(&book_id).await?;
    chapter_ir::load_chapter_content_ir(&file_path, chapter_index).await
}
