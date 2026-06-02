//! 笔记管理 API
//!
//! 提供笔记的 CRUD 操作和查询功能。

use flutter_rust_bridge::frb;

use super::async_storage;
use crate::domain::AppError;
use crate::storage::repos::NoteRepository;

pub use crate::storage::models::{Note, NoteStats, NoteType};

/// 创建高亮笔记（自动生成 UUID）
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
/// * `char_offset` - 字符偏移
/// * `length` - 高亮长度
/// * `selected_text` - 选中的文本
/// * `color` - 高亮颜色
/// * `language` - 语言（可选）
/// * `paired_note_id` - 关联的批注 ID（可选）
///
/// # 返回
/// 创建完成的高亮笔记对象
#[allow(clippy::too_many_arguments)]
#[frb]
pub async fn create_highlight(
    book_id: String,
    chapter_index: i32,
    char_offset: i64,
    length: i64,
    selected_text: String,
    color: i32,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    let note = Note::highlight(
        &book_id,
        chapter_index,
        char_offset,
        length,
        &selected_text,
        color,
        language.as_deref(),
        paired_note_id.as_deref(),
    );
    async_storage!(|pool| NoteRepository::save(pool, &note))
}

/// 创建批注笔记（自动生成 UUID）
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
/// * `char_offset` - 字符偏移
/// * `content` - 批注内容
/// * `selected_text` - 关联的选中文本（可选）
/// * `language` - 语言（可选）
/// * `paired_note_id` - 关联的高亮 ID（可选）
///
/// # 返回
/// 创建完成的批注笔记对象
#[frb]
pub async fn create_annotation(
    book_id: String,
    chapter_index: i32,
    char_offset: i64,
    content: String,
    selected_text: Option<String>,
    language: Option<String>,
    paired_note_id: Option<String>,
) -> Result<Note, AppError> {
    let note = Note::annotation(
        &book_id,
        chapter_index,
        char_offset,
        &content,
        selected_text.as_deref(),
        language.as_deref(),
        paired_note_id.as_deref(),
    );
    async_storage!(|pool| NoteRepository::save(pool, &note))
}

/// 新增或更新笔记(upsert)
///
/// # 参数
/// * `note` - 笔记对象
///
/// # 返回
/// 成功时返回 Ok(Note), 失败时返回 AppError
#[frb]
pub async fn upsert_note(note: Note) -> Result<Note, AppError> {
    async_storage!(|pool| NoteRepository::save(pool, &note))
}

/// 获取书籍的所有笔记列表
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `note_type` - 笔记类型筛选(可选, None表示所有类型)
///
/// # 返回
/// 该书籍的笔记列表
#[frb]
pub async fn list_notes_by_book(
    book_id: String,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    async_storage!(|pool| async move {
        match note_type {
            Some(nt) => NoteRepository::find_by_type(pool, &book_id, nt).await,
            None => NoteRepository::list_by_book(pool, &book_id).await,
        }
    })
}

#[frb]
pub async fn list_notes_by_books(
    book_ids: Vec<String>,
) -> Result<Vec<(String, Vec<Note>)>, AppError> {
    async_storage!(|pool| async move {
        // 1. 单次 I/O 获取所有笔记并按 book_id 分组
        let notes_map = NoteRepository::list_by_books_batch(pool, &book_ids).await?;

        // 2. 按原始入参顺序组装结果，缺失的 book_id 返回空 Vec
        let result = book_ids
            .into_iter()
            .map(|id| {
                let notes = notes_map.get(&id).cloned().unwrap_or_default();
                (id, notes)
            })
            .collect();

        Ok::<_, AppError>(result)
    })
}
/// 获取章节内的笔记列表
///
/// # 参数
/// * `book_id` - 书籍 ID
/// * `chapter_index` - 章节索引
/// * `note_type` - 笔记类型筛选(可选)
///
/// # 返回
/// 该章节内的笔记列表
#[frb]
pub async fn list_notes_in_chapter(
    book_id: String,
    chapter_index: i32,
    note_type: Option<NoteType>,
) -> Result<Vec<Note>, AppError> {
    async_storage!(|pool| async move {
        match note_type {
            Some(nt) => {
                NoteRepository::find_by_type_in_chapter(pool, &book_id, chapter_index, nt).await
            }
            None => {
                NoteRepository::find_paired_notes_in_chapter(pool, &book_id, chapter_index).await
            }
        }
    })
}

/// 删除笔记
///
/// # 参数
/// * `note_id` - 笔记 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn delete_note(note_id: String) -> Result<(), AppError> {
    async_storage!(|pool| NoteRepository::delete_by_id(pool, &note_id))
}

/// 清除书籍的所有笔记
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
#[frb]
pub async fn clear_notes_by_book(book_id: String) -> Result<(), AppError> {
    async_storage!(|pool| NoteRepository::delete_by_book(pool, &book_id))
}

/// 获取笔记统计信息
///
/// # 参数
/// * `book_id` - 书籍 ID
///
/// # 返回
/// 该书籍的笔记统计信息
#[frb]
pub async fn get_note_stats(book_id: String) -> Result<NoteStats, AppError> {
    async_storage!(|pool| NoteRepository::find_note_stats(pool, &book_id))
}

/// 渲染笔记列表为指定格式的字符串
///
/// 支持 txt / markdown / html 三种导出格式。
/// 此函数不涉及 I/O，仅做字符串拼接。
///
/// # 参数
/// * `notes` - 笔记列表
/// * `book_title` - 书名
/// * `format` - 导出格式: "txt", "markdown", "html"
///
/// # 返回
/// 格式化后的完整导出文本
#[frb(sync)]
pub fn render_notes_to_string(notes: Vec<Note>, book_title: String, format: String) -> String {
    match format.as_str() {
        "html" => render_html(notes, &book_title),
        "markdown" => render_markdown(notes, &book_title),
        _ => render_txt(notes, &book_title),
    }
}

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
        if let Some(ref sel) = note.selected_text {
            if !sel.is_empty() {
                let _ = std::fmt::Write::write_fmt(&mut buf, format_args!("原文: \"{}\"\n", sel));
            }
        }
        let _ = std::fmt::Write::write_fmt(
            &mut buf,
            format_args!("时间: {}\n", format_timestamp(&note.created_at)),
        );
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
        let _ = std::fmt::Write::write_fmt(
            &mut buf,
            format_args!("- **章节**: 第 {} 章\n", note.chapter_index + 1),
        );
        if let Some(ref sel) = note.selected_text {
            if !sel.is_empty() {
                let _ =
                    std::fmt::Write::write_fmt(&mut buf, format_args!("- **原文**: \"{}\"\n", sel));
            }
        }
        let _ = std::fmt::Write::write_fmt(
            &mut buf,
            format_args!("- **时间**: {}\n\n", format_timestamp(&note.created_at)),
        );
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
        let _ = std::fmt::Write::write_fmt(
            &mut body,
            format_args!("      <h2>{} #{}</h2>\n", label, i + 1),
        );
        let _ = std::fmt::Write::write_fmt(
            &mut body,
            format_args!(
                "      <p class=\"meta\">章节: 第 {} 章</p>\n",
                note.chapter_index + 1
            ),
        );
        if let Some(ref sel) = note.selected_text {
            if !sel.is_empty() {
                let _ = std::fmt::Write::write_fmt(
                    &mut body,
                    format_args!("      <blockquote>{}</blockquote>\n", escape_html(sel)),
                );
            }
        }
        let _ = std::fmt::Write::write_fmt(
            &mut body,
            format_args!(
                "      <p class=\"meta\">{}</p>\n",
                format_timestamp(&note.created_at)
            ),
        );
        if !note.content.is_empty() && note.selected_text.as_deref() != Some(&note.content) {
            let _ = std::fmt::Write::write_fmt(
                &mut body,
                format_args!(
                    "      <p class=\"content\">{}</p>\n",
                    escape_html(&note.content)
                ),
            );
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
