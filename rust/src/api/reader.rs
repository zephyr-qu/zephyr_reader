//! 章节读取 API — FRB 薄封装层

use std::collections::HashMap;
use std::sync::LazyLock;

use flutter_rust_bridge::frb;
use parking_lot::Mutex;

use crate::common::AppError;
use crate::domain::book::book_repo::BookRepository;
use crate::infra::manager::storage_pool;
use crate::pipeline::{chapter_ir, ChapterContentIr};

/// 全局行断点缓存
type LineBreaksStore = LazyLock<Mutex<HashMap<(String, i32, u64), Vec<u32>>>>;
static LINE_BREAKS_STORE: LineBreaksStore = LazyLock::new(|| Mutex::new(HashMap::new()));

async fn resolve_book_path(book_id: &str) -> Result<String, AppError> {
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

/// 存储 Flutter 行断点
#[frb(sync)]
pub fn store_line_breaks(
    book_id: String,
    chapter_index: i32,
    config_hash: u64,
    line_breaks: Vec<u32>,
) -> Result<(), AppError> {
    let mut store = LINE_BREAKS_STORE.lock();
    store.insert((book_id, chapter_index, config_hash), line_breaks);
    Ok(())
}

/// 加载整章 ContentBlock IR
#[frb]
pub async fn get_chapter_content_ir(
    book_id: String,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    let file_path = resolve_book_path(&book_id).await?;
    chapter_ir::load_chapter_content_ir(&file_path, chapter_index).await
}
