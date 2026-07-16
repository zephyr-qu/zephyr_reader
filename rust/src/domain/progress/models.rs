use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use crate::domain::book::Book;

/// 单章阅读进度
///
/// 进度只持久化 chapterIndex + charOffset（ADR-001 / I1）。
/// page_index / total_pages 已移除——它们是分页视图的派生值，不属于持久化真理。
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, sqlx::FromRow)]
#[frb(dart_metadata = ("freezed"))]
pub struct ReadingProgress {
    pub book_id: String,
    pub chapter_index: i64,
    pub chunk_index: i64,
    pub chapter_id: Option<String>,
    pub char_offset: i64,
    pub progress: f32,
    pub reading_time_seconds: i64,
    pub last_read_at: DateTime<Utc>,
    pub is_completed: bool,
}

impl ReadingProgress {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        book_id: &str,
        chapter_index: i64,
        chunk_index: i64,
        char_offset: i64,
        progress: f32,
        reading_time_seconds: i64,
        is_completed: bool,
    ) -> Self {
        Self {
            book_id: book_id.to_string(),
            chapter_index,
            chunk_index,
            chapter_id: None,
            char_offset,
            progress,
            reading_time_seconds,
            last_read_at: Utc::now(),
            is_completed,
        }
    }
}

/// 书籍+阅读进度聚合（LEFT JOIN 查询结果）
#[derive(Debug, Clone, Serialize, Deserialize)]
#[frb(dart_metadata=("freezed"))]
pub struct BookWithProgress {
    pub book: Book,
    pub progress: Option<ReadingProgress>,
}

/// BookWithProgress 的扁平 SQL 映射行
///
/// 对应 `SELECT b.*, rp.chapter_index AS progress_chapter_index, ...` 查询结果。
/// 不能直接在 BookWithProgress 上 derive FromRow，因为嵌套结构不被支持。
/// 这个扁平中间行用于 query_as，然后通过 From 转换为 BookWithProgress。
#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct BookWithProgressRow {
    // Book 字段 — 对应 `b.*`（注意 book.id 映射到 book_id）
    #[sqlx(rename = "id")]
    book_id: String,
    file_path: String,
    file_hash: Option<String>,
    file_size: i64,
    file_mtime: Option<i64>,
    title: String,
    author: Option<String>,
    cover_path: Option<String>,
    chapter_count: i64,
    total_characters: i64,
    #[sqlx(try_from = "String")]
    format: crate::domain::book::BookFormat,
    added_at: chrono::DateTime<chrono::Utc>,
    last_opened_at: Option<chrono::DateTime<chrono::Utc>>,
    #[sqlx(try_from = "String")]
    status: crate::domain::book::BookStatus,
    is_pinned: bool,
    description: Option<String>,
    publisher: Option<String>,
    translator: Option<String>,
    isbn: Option<String>,
    // ReadingProgress 字段 — LEFT JOIN 所以全部 Option
    progress_chapter_index: Option<i64>,
    progress_char_offset: Option<i64>,
    progress_percent: Option<f32>,
    progress_last_read_at: Option<chrono::DateTime<chrono::Utc>>,
    progress_is_completed: Option<bool>,
}

impl From<BookWithProgressRow> for BookWithProgress {
    fn from(row: BookWithProgressRow) -> Self {
        let book = Book {
            book_id: row.book_id,
            file_path: row.file_path,
            file_hash: row.file_hash,
            file_size: row.file_size,
            file_mtime: row.file_mtime,
            title: row.title,
            author: row.author,
            cover_path: row.cover_path,
            chapter_count: row.chapter_count,
            total_characters: row.total_characters,
            format: row.format,
            added_at: row.added_at,
            last_opened_at: row.last_opened_at,
            status: row.status,
            is_pinned: row.is_pinned,
            description: row.description,
            publisher: row.publisher,
            translator: row.translator,
            isbn: row.isbn,
        };
        let progress = row.progress_chapter_index.map(|chapter_index| {
            ReadingProgress {
                book_id: book.book_id.clone(),
                chapter_index,
                chunk_index: 0, // chunk_index 未在查询中, 默认 0
                chapter_id: None,
                char_offset: row.progress_char_offset.unwrap_or(0),
                progress: row.progress_percent.unwrap_or(0.0),
                reading_time_seconds: 0,
                last_read_at: row.progress_last_read_at.unwrap_or_else(chrono::Utc::now),
                is_completed: row.progress_is_completed.unwrap_or(false),
            }
        });
        BookWithProgress { book, progress }
    }
}
