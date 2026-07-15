//! 笔记业务逻辑
//!
//! 提供笔记的查询业务和导出渲染功能。
//! 数据访问委托给 NoteRepository。

use crate::common::AppError;
use crate::domain::note::{Note, NoteStats, NoteType, NoteWithBook};
use crate::infra::manager::storage_pool;
use crate::domain::note::note_repo::NoteRepository;

// ==================== 数据查询 ====================

/// 搜索笔记（内容/选中文本模糊匹配）
pub async fn search_notes(query: &str) -> Result<Vec<Note>, AppError> {
    let pool = storage_pool()?;
    NoteRepository::search(&pool, query).await
}

/// 跨书分页获取所有笔记
pub async fn list_all_notes(limit: i64, offset: i64) -> Result<Vec<Note>, AppError> {
    let pool = storage_pool()?;
    NoteRepository::list_all_paginated(&pool, limit, offset).await
}

/// 分页获取笔记列表（带书名）
pub async fn list_notes_with_titles(limit: i64, offset: i64) -> Result<Vec<NoteWithBook>, AppError> {
    let pool = storage_pool()?;
    NoteRepository::list_with_titles(&pool, limit, offset).await
}

/// 获取笔记总数（可选按 book_id 过滤）
pub async fn count_notes(book_id: Option<&str>) -> Result<i32, AppError> {
    let pool = storage_pool()?;
    NoteRepository::count_filtered(&pool, book_id).await
}

/// 获取笔记统计
pub async fn get_note_stats(book_id: &str) -> Result<NoteStats, AppError> {
    let pool = storage_pool()?;
    NoteRepository::find_note_stats(&pool, book_id).await
}

/// 获取书籍的所有笔记
pub async fn list_notes_by_book(book_id: &str, note_type: Option<NoteType>) -> Result<Vec<Note>, AppError> {
    let pool = storage_pool()?;
    match note_type {
        Some(nt) => NoteRepository::find_by_type(&pool, book_id, nt).await,
        None => NoteRepository::list_by_book(&pool, book_id).await,
    }
}

/// 批量获取多本书的笔记
pub async fn list_notes_by_books(book_ids: &[String]) -> Result<Vec<(String, Vec<Note>)>, AppError> {
    let pool = storage_pool()?;
    let notes_map = NoteRepository::list_by_books_batch(&pool, book_ids).await?;
    let result = book_ids
        .iter()
        .map(|id| {
            let notes = notes_map.get(id).cloned().unwrap_or_default();
            (id.clone(), notes)
        })
        .collect();
    Ok(result)
}

/// 获取章节内的笔记
pub async fn list_notes_in_chapter(
    book_id: &str,
    chapter_index: i64,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    let pool = storage_pool()?;
    match note_type {
        Some(nt) => NoteRepository::find_by_type_in_chapter(&pool, book_id, chapter_index, nt).await,
        None => NoteRepository::find_paired_notes_in_chapter(&pool, book_id, chapter_index).await,
    }
}

// ==================== 数据写入 ====================

/// 创建高亮笔记
#[allow(clippy::too_many_arguments)]
pub async fn create_highlight(
    book_id: &str,
    chapter_index: i64,
    char_offset: i64,
    length: i64,
    selected_text: &str,
    color: i64,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    let note = Note::highlight(book_id, chapter_index, char_offset, length, selected_text, color, language, paired_note_id);
    let pool = storage_pool()?;
    NoteRepository::save(&pool, &note).await
}

/// 创建批注笔记
pub async fn create_annotation(
    book_id: &str,
    chapter_index: i64,
    char_offset: i64,
    content: &str,
    selected_text: Option<String>,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    let note = Note::annotation(book_id, chapter_index, char_offset, content, selected_text, language, paired_note_id);
    let pool = storage_pool()?;
    NoteRepository::save(&pool, &note).await
}

/// 新增或更新笔记
pub async fn upsert_note(note: &Note) -> Result<Note, AppError> {
    let pool = storage_pool()?;
    NoteRepository::save(&pool, note).await
}

// ==================== 数据删除 ====================

/// 删除单个笔记
pub async fn delete_note(note_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    NoteRepository::delete_by_id(&pool, note_id).await
}

/// 清空书籍的所有笔记
pub async fn clear_notes_by_book(book_id: &str) -> Result<(), AppError> {
    let pool = storage_pool()?;
    NoteRepository::delete_by_book(&pool, book_id).await
}

// ==================== 数据查询 ====================

fn note_type_label(note_type: &NoteType) -> &'static str {
    match note_type {
        NoteType::Highlight => "高亮",
        NoteType::Annotation => "笔记",
    }
}

fn format_timestamp(ts: &chrono::DateTime<chrono::Utc>) -> String {
    ts.format("%Y-%m-%d %H:%M:%S").to_string()
}

fn escape_html(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
}

/// 渲染笔记列表为指定格式
pub fn render_notes_to_string(notes: Vec<Note>, book_title: &str, format: &str) -> String {
    match format {
        "html" => render_html(notes, book_title),
        "markdown" => render_markdown(notes, book_title),
        _ => render_txt(notes, book_title),
    }
}

fn render_txt(notes: Vec<Note>, book_title: &str) -> String {
    let mut buf = String::new();
    buf.push_str(book_title);
    buf.push_str(" - 读书笔记\n");
    buf.push_str(&"=".repeat(30));
    buf.push_str("\n\n");
    for (i, note) in notes.iter().enumerate() {
        let label = note_type_label(&note.note_type);
        let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("{} #{}\n", label, i + 1));
        let _ = std::fmt::Write::write_fmt(
            &mut buf,
            format_args!("章节: 第 {} 章\n", note.chapter_index + 1),
        );
        if let Some(ref sel) = note.selected_text && !sel.is_empty() {
            let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("原文: \"{}\"\n", sel));
        }
        let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("时间: {}\n", format_timestamp(&note.created_at)));
        if !note.content.is_empty() && note.selected_text.as_deref() != Some(&note.content) {
            let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("笔记: {}\n", note.content));
        }
        buf.push_str("---\n\n");
    }
    buf.push_str("由 Zephyr Reader 导出\n");
    buf
}

fn render_markdown(notes: Vec<Note>, book_title: &str) -> String {
    let mut buf = String::new();
    let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("# {} - 读书笔记\n", book_title));
    buf.push_str("---\n\n");
    for (i, note) in notes.iter().enumerate() {
        let label = note_type_label(&note.note_type);
        let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("## {} #{}\n\n", label, i + 1));
        let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("- **章节**: 第 {} 章\n", note.chapter_index + 1));
        if let Some(ref sel) = note.selected_text && !sel.is_empty() {
            let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("- **原文**: \"{}\"\n", sel));
        }
        let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("- **时间**: {}\n\n", format_timestamp(&note.created_at)));
        if !note.content.is_empty() && note.selected_text.as_deref() != Some(&note.content) {
            let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("> {}\n\n", note.content));
        }
        buf.push_str("---\n\n");
    }
    buf.push_str("*由 Zephyr Reader 导出*\n");
    buf
}

fn render_html(notes: Vec<Note>, book_title: &str) -> String {
    let mut body = String::new();
    for (i, note) in notes.iter().enumerate() {
        let label = note_type_label(&note.note_type);
        body.push_str("    <div class=\"note\">\n");
        let _ = std::fmt::Write::write_fmt(&mut body, format_args!("      <h2>{} #{}</h2>\n", label, i + 1));
        let _ = std::fmt::Write::write_fmt(&mut body, format_args!("      <p class=\"meta\">章节: 第 {} 章</p>\n", note.chapter_index + 1));
        if let Some(ref sel) = note.selected_text && !sel.is_empty() {
            let _ = std::fmt::Write::write_fmt(&mut body, format_args!("      <blockquote>{}</blockquote>\n", escape_html(sel)));
        }
        let _ = std::fmt::Write::write_fmt(&mut body, format_args!("      <p class=\"meta\">{}</p>\n", format_timestamp(&note.created_at)));
        if !note.content.is_empty() && note.selected_text.as_deref() != Some(&note.content) {
            let _ = std::fmt::Write::write_fmt(&mut body, format_args!("      <p class=\"content\">{}</p>\n", escape_html(&note.content)));
        }
        body.push_str("      <hr>\n");
        body.push_str("    </div>\n");
    }

    format!(
        r#"<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{title} - 读书笔记</title>
<style>
  body {{ font-family: -apple-system, "Noto Sans SC", sans-serif; max-width: 720px; margin: 0 auto; padding: 20px; color: #333; line-height: 1.7; }}
  h1 {{ color: #1a1a1a; border-bottom: 2px solid #eee; padding-bottom: 8px; }}
  h2 {{ color: #2c3e50; font-size: 1.1em; margin-top: 24px; }}
  blockquote {{ border-left: 3px solid #ffd54f; margin: 8px 0; padding: 8px 16px; background: #fffde7; color: #555; border-radius: 0 4px 4px 0; }}
  .meta {{ color: #888; font-size: 0.88em; }}
  .content {{ background: #f8f9fa; padding: 12px 16px; border-radius: 6px; margin: 8px 0; }}
  hr {{ border: none; border-top: 1px solid #eee; margin: 16px 0; }}
  .footer {{ text-align: center; color: #aaa; font-size: 0.85em; margin-top: 32px; }}
</style>
</head>
<body>
  <h1>{title} - 读书笔记</h1>
{body}
  <p class="footer">由 Zephyr Reader 导出</p>
</body>
</html>"#,
        title = book_title,
        body = body,
    )
}
