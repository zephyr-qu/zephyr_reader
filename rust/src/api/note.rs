//! 笔记管理 API — FRB 薄封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::note::{Note, NoteStats, NoteType, NoteWithBook};
use crate::domain::note::service;

// ============================================================
// 笔记 CRUD — 薄 FFI 封装
// ============================================================

/// 创建高亮笔记
#[allow(clippy::too_many_arguments)]
#[frb]
pub async fn create_highlight(
    book_id: String,
    chapter_index: i32,
    char_offset: i32,
    length: i32,
    selected_text: String,
    color: i32,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    tracing::info!("[note] create_highlight: book_id={}, chapter_index={}", book_id, chapter_index);
    service::create_highlight(
        &book_id, chapter_index as i64, char_offset as i64, length as i64,
        &selected_text, color as i64, language, paired_note_id,
    ).await
}

/// 创建批注笔记
#[frb]
pub async fn create_annotation(
    book_id: String,
    chapter_index: i32,
    char_offset: i32,
    content: String,
    selected_text: Option<String>,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    tracing::info!("[note] create_annotation: book_id={}, chapter_index={}", book_id, chapter_index);
    service::create_annotation(
        &book_id, chapter_index as i64, char_offset as i64,
        &content, selected_text, language, paired_note_id,
    ).await
}

/// 新增或更新笔记
#[frb]
pub async fn upsert_note(note: Note) -> Result<Note, AppError> {
    service::upsert_note(&note).await
}

/// 获取书籍的所有笔记列表
#[frb]
pub async fn list_notes_by_book(
    book_id: String,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    tracing::debug!("[note] list_notes_by_book: book_id={}", book_id);
    service::list_notes_by_book(&book_id, note_type).await
}

/// 批量获取多本书籍的笔记
#[frb]
pub async fn list_notes_by_books(
    book_ids: Vec<String>,
) -> Result<Vec<(String, Vec<Note>)>, AppError> {
    service::list_notes_by_books(&book_ids).await
}

/// 搜索笔记
#[frb]
pub async fn search_notes(query: String) -> Result<Vec<Note>, AppError> {
    tracing::debug!("[note] search_notes: query={}", query);
    service::search_notes(&query).await
}

/// 跨书分页获取所有笔记
#[frb]
pub async fn list_all_notes(limit: i32, offset: i32) -> Result<Vec<Note>, AppError> {
    tracing::debug!("[note] list_all_notes: limit={}, offset={}", limit, offset);
    service::list_all_notes(limit as i64, offset as i64).await
}

/// 分页查询笔记列表（带书名）
#[frb]
pub async fn list_notes_with_titles(
    limit: i32,
    offset: i32,
) -> Result<Vec<NoteWithBook>, AppError> {
    service::list_notes_with_titles(limit as i64, offset as i64).await
}

/// 获取笔记总数
#[frb]
pub async fn count_notes(book_id: Option<String>) -> Result<i32, AppError> {
    service::count_notes(book_id.as_deref()).await
}

/// 获取章节内的笔记列表
#[frb]
pub async fn list_notes_in_chapter(
    book_id: String,
    chapter_index: i32,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    tracing::debug!("[note] list_notes_in_chapter: book_id={}, chapter_index={}", book_id, chapter_index);
    service::list_notes_in_chapter(&book_id, chapter_index as i64, note_type).await
}

/// 删除笔记
#[frb]
pub async fn delete_note(note_id: String) -> Result<(), AppError> {
    tracing::info!("[note] delete_note: note_id={}", note_id);
    service::delete_note(&note_id).await
}

/// 清除书籍的所有笔记
#[frb]
pub async fn delete_notes_by_book(book_id: String) -> Result<(), AppError> {
    tracing::info!("[note] delete_notes_by_book: book_id={}", book_id);
    service::delete_notes_by_book(&book_id).await
}

/// 获取笔记统计信息
#[frb]
pub async fn get_note_stats(book_id: String) -> Result<NoteStats, AppError> {
    tracing::debug!("[note] get_note_stats: book_id={}", book_id);
    service::get_note_stats(&book_id).await
}

/// 渲染笔记列表为指定格式的字符串
#[frb(sync)]
pub fn render_notes_to_string(notes: Vec<Note>, book_title: String, format: String) -> String {
    service::render_notes_to_string(notes, &book_title, &format)
}
