use std::collections::HashMap;
use std::sync::LazyLock;

use parking_lot::Mutex;

use crate::domain::{AppError, ChapterContentIr};
use crate::reading::{chapter_access, chapter_ir};
use crate::storage::repos::BookRepository;
use crate::storage::storage_pool;
use flutter_rust_bridge::frb;

// ============================================================
// 文件作用：章节读取 API — 获取原始文本、IR、存储行断点。
//
// 公有函数：
//   - get_chapter() — 获取指定章节原始文本
//   - store_line_breaks() — 存储 Flutter 行断点
//   - get_chapter_content_ir() — 加载整章 ContentBlock IR
//
// 私有函数：
//   - resolve_book_path() — 从 book_id 解析 file_path
// ============================================================

/// 全局行断点缓存 (book_id, chapter_index, config_hash) → Vec<u32>。
static LINE_BREAKS_STORE: LazyLock<Mutex<HashMap<(String, i32, u64), Vec<u32>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// 从 book_id 解析 file_path（ADR-014 — handle-based 统一）。
async fn resolve_book_path(book_id: &str) -> Result<String, AppError> {
    let pool = storage_pool()?;
    let book = BookRepository::find_by_id(&pool, book_id)
        .await?
        .ok_or_else(|| AppError::NotFound {
            entity: format!("book {book_id}"),
        })?;
    Ok(book.file_path)
}

/// 获取指定章节的原始文本内容。
/// 分页已迁移至 Flutter 侧，Rust 仅返回原始文本。
///
/// NOTE: Phase 8 后 scroll 模式已走 IR（`get_chapter_content_ir`），
/// 本函数仅作为 IR 失败时的廉价退化备选（plain text fallback）
/// 及 preload 热身缓存。待 IR 路径完全可靠后可考虑移除。
#[frb]
pub async fn get_chapter(
    file_path: String,
    chapter_index: i32,
) -> Result<String, AppError> {
    chapter_access::get_chapter(file_path, chapter_index).await
}

/// 存储 Flutter 预计算的行断点（首屏 / scroll 预加载时填充）。
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

/// 加载整章 ContentBlock IR + plain 投影（scroll 路径；不创建 session）。
#[frb]
pub async fn get_chapter_content_ir(
    book_id: String,
    chapter_index: i32,
) -> Result<ChapterContentIr, AppError> {
    let file_path = resolve_book_path(&book_id).await?;
    chapter_ir::load_chapter_content_ir(&file_path, chapter_index).await
}
