//! SQLite 数据库管理
//! 使用 rusqlite 管理阅读进度、书签、笔记、同步状态
//! 书籍、章节和分类等数据
use std::path::Path;

use anyhow::{Context, Result};
use rusqlite::{params, Connection, OptionalExtension};

use crate::storage::models::NoteStats;

use super::models::*;

/// 数据库版本（当前固定为 v1：全量建表）
const DB_VERSION: i32 = 1;

/// SQLite INTEGER (Unix timestamp) → chrono::DateTime<Utc>
/// 如果时间戳无效，返回当前时间（避免崩溃）
#[inline]
fn ts_to_dt(ts: i64) -> chrono::DateTime<chrono::Utc> {
    chrono::DateTime::from_timestamp(ts, 0).unwrap_or_else(chrono::Utc::now)
}
/// Option<i64> → Option<DateTime<Utc>>，用于可为空的时间字段
#[inline]
fn ts_to_opt_dt(ts: Option<i64>) -> Option<chrono::DateTime<chrono::Utc>> {
    ts.and_then(|t| chrono::DateTime::from_timestamp(t, 0))
}

/// 从 Row 映射阅读会话
#[inline]
fn row_to_reading_session(row: &rusqlite::Row<'_>) -> rusqlite::Result<DbReadingSession> {
    Ok(DbReadingSession {
        id: row.get("id")?,
        book_id: row.get("book_id")?,
        chapter_index: row.get("chapter_index")?,
        start_char_offset: row.get("start_char_offset")?,
        end_char_offset: row.get("end_char_offset")?,
        started_at: ts_to_dt(row.get("started_at")?),
        ended_at: ts_to_dt(row.get("ended_at")?),
        duration_seconds: row.get("duration_seconds")?,
        characters_read: row.get("characters_read")?,
    })
}

/// 从 Row 映射章节
#[inline]
fn row_to_chapter(row: &rusqlite::Row<'_>) -> rusqlite::Result<DbChapter> {
    Ok(DbChapter {
        id: row.get("id")?,
        book_id: row.get("book_id")?,
        title: row.get("title")?,
        content_file: row.get("content_file")?,
        chapter_index: row.get("chapter_index")?,
        word_count: row.get("word_count")?,
        cached_at: ts_to_dt(row.get("cached_at")?),
        level: row.get("level")?,
    })
}

/// 从 Row 映射书籍分类
#[inline]
fn row_to_book_category(row: &rusqlite::Row<'_>) -> rusqlite::Result<DbBookCategory> {
    Ok(DbBookCategory {
        id: row.get("id")?,
        name: row.get("name")?,
        description: row.get("description")?,
        color: row.get("color")?,
        sort_order: row.get("sort_order")?,
        is_system: row.get::<_, i32>("is_system")? != 0,
        created_at: ts_to_dt(row.get("created_at")?),
        updated_at: ts_to_dt(row.get("updated_at")?),
    })
}

/// 数据库管理器
pub struct Database {
    conn: Connection,
}

impl Database {
    /// 创建或打开数据库
    pub fn new(db_path: impl AsRef<Path>) -> Result<Self> {
        let conn = Connection::open(db_path).context("Failed to open database")?;
        // 启用外键约束
        conn.execute("PRAGMA foreign_keys = ON", [])?;
        // 使用 WAL 模式提升并发性能
        conn.pragma_update(None, "journal_mode", "WAL")?;
        conn.pragma_update(None, "synchronous", "NORMAL")?;
        // 设置繁忙超时（5秒）
        conn.busy_timeout(std::time::Duration::from_secs(5))?;
        // 启用 WAL 自动检查点
        conn.pragma_update(None, "wal_autocheckpoint", 1000)?;
        conn.pragma_update(None, "cache_size", "-2000")?;
        conn.pragma_update(None, "temp_store", "MEMORY")?;
        let mut db = Self { conn };
        db.migrate()?;
        Ok(db)
    }

    /// 数据库初始化逻辑
    fn migrate(&mut self) -> Result<()> {
        let version: i32 = self
            .conn
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap_or(0);

        if version == 0 {
            // 首次创建：全量建表
            self.create_tables()?;
            self.conn.pragma_update(None, "user_version", DB_VERSION)?;
        } else if version < DB_VERSION {
            anyhow::bail!(
                "数据库版本过旧 (v{})，与当前版本 (v{}) 不兼容。请备份数据后删除旧数据库文件重新生成。",
                version, DB_VERSION
            );
        }
        Ok(())
    }

    /// 创建所有数据表（v1 全量建表）
    fn create_tables(&self) -> Result<()> {
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS books (
                book_id TEXT PRIMARY KEY, file_path TEXT NOT NULL UNIQUE,
                file_size INTEGER NOT NULL, title TEXT NOT NULL, author TEXT,
                description TEXT, cover_path TEXT, chapter_count INTEGER DEFAULT 0,
                total_characters INTEGER DEFAULT 0, format TEXT NOT NULL,
                added_at INTEGER NOT NULL, last_opened_at INTEGER,
                status TEXT DEFAULT 'reading', is_pinned INTEGER DEFAULT 0
            )",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS reading_progress (
                book_id TEXT PRIMARY KEY, chapter_index INTEGER NOT NULL DEFAULT 0,
                char_offset INTEGER NOT NULL DEFAULT 0, page_index INTEGER NOT NULL DEFAULT 0,
                total_pages INTEGER NOT NULL DEFAULT 0, progress REAL NOT NULL DEFAULT 0.0,
                reading_time_seconds INTEGER NOT NULL DEFAULT 0, last_read_at INTEGER NOT NULL,
                is_completed INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;
        // 书架按最后阅读时间排序的索引
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_progress_last_read ON reading_progress(last_read_at)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_books_status_last_open ON books(status, last_opened_at)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_books_pinned_last_open ON books(is_pinned, last_opened_at)",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS bookmarks (
                id TEXT PRIMARY KEY, book_id TEXT NOT NULL, chapter_index INTEGER NOT NULL,
                char_offset INTEGER NOT NULL, title TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_bookmarks_book ON bookmarks(book_id)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_bookmarks_chapter ON bookmarks(book_id, chapter_index)",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS reading_sessions (
                id TEXT PRIMARY KEY, book_id TEXT NOT NULL, chapter_index INTEGER NOT NULL,
                start_char_offset INTEGER NOT NULL, end_char_offset INTEGER NOT NULL,
                started_at INTEGER NOT NULL, ended_at INTEGER NOT NULL,
                duration_seconds INTEGER NOT NULL, characters_read INTEGER NOT NULL,
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sessions_book ON reading_sessions(book_id)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON reading_sessions(started_at)",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS daily_read_books (
                date TEXT NOT NULL,
                book_id TEXT NOT NULL,
                PRIMARY KEY (date, book_id),
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS daily_stats (
                date TEXT NOT NULL PRIMARY KEY,
                reading_time_seconds INTEGER NOT NULL DEFAULT 0,
                characters_read INTEGER NOT NULL DEFAULT 0,
                session_count INTEGER NOT NULL DEFAULT 0,
                chapters_read INTEGER DEFAULT 0,
                pages_read INTEGER DEFAULT 0
            )",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, description TEXT,
                color TEXT, sort_order INTEGER DEFAULT 0, created_at INTEGER NOT NULL,
                is_system INTEGER DEFAULT 0, updated_at INTEGER
            )",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS book_categories (
                book_id TEXT NOT NULL, category_id TEXT NOT NULL,
                PRIMARY KEY (book_id, category_id),
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
                FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
            )",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS chapters (
                id TEXT PRIMARY KEY, book_id TEXT NOT NULL, title TEXT NOT NULL,
                content_file TEXT NOT NULL, chapter_index INTEGER NOT NULL,
                word_count INTEGER DEFAULT 0, cached_at INTEGER NOT NULL,
                level INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_chapters_book ON chapters(book_id)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_chapters_index ON chapters(book_id, chapter_index)",
            [],
        )?;

        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY, book_id TEXT NOT NULL, chapter_index INTEGER NOT NULL,
                char_offset INTEGER NOT NULL, length INTEGER NOT NULL DEFAULT 0,
                note_type TEXT NOT NULL, content TEXT NOT NULL DEFAULT '',
                selected_text TEXT, highlight_color INTEGER, created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE
            )",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_notes_book ON notes(book_id)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_notes_chapter ON notes(book_id, chapter_index)",
            [],
        )?;
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_notes_type ON notes(book_id, note_type)",
            [],
        )?;
        self.conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_unique ON notes(book_id, chapter_index, char_offset, note_type)",
            [],
        )?;

        // FTS5 全文搜索索引（与主数据库同文件，支持事务）
        self.conn.execute_batch(
            "CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
                book_id,
                chapter_id,
                chapter_title,
                content,
                position UNINDEXED
            )",
        )?;

        Ok(())
    }

    /// 获取原生连接（用于高级操作）
    pub fn conn(&self) -> &Connection {
        &self.conn
    }

    /// 获取可变原生连接（用于事务等需要可变访问的操作）
    pub fn conn_mut(&mut self) -> &mut Connection {
        &mut self.conn
    }

    // ==================== Book Operations ====================

    fn row_to_book_record(
        &self,
        row: &rusqlite::Row,
    ) -> std::result::Result<DbBookRecord, rusqlite::Error> {
        Ok(DbBookRecord {
            book_id: row.get("book_id")?,
            file_path: row.get("file_path")?,
            file_size: row.get("file_size")?,
            title: row.get("title")?,
            author: row.get("author")?,
            description: row.get("description")?,
            cover_path: row.get("cover_path")?,
            chapter_count: row.get("chapter_count")?,
            total_characters: row.get("total_characters")?,
            format: match row.get::<_, String>("format")?.as_str() {
                "epub" => DbBookFormat::Epub,
                "txt" => DbBookFormat::Txt,
                "pdf" => DbBookFormat::Pdf,
                _ => DbBookFormat::Txt,
            },
            added_at: ts_to_dt(row.get("added_at")?),
            last_opened_at: ts_to_opt_dt(row.get("last_opened_at")?),
            status: match row.get::<_, String>("status")?.as_str() {
                "completed" => DbBookStatus::Completed,
                "dropped" => DbBookStatus::Dropped,
                "planned" => DbBookStatus::Planned,
                _ => DbBookStatus::Reading,
            },
            is_pinned: row.get::<_, i32>("is_pinned")? != 0,
        })
    }

    pub fn save_book(&self, book: &DbBookRecord) -> Result<()> {
        self.conn.execute(
            "INSERT INTO books (
                book_id, file_path, file_size, title, author,
                description, cover_path, chapter_count, total_characters,
                format, added_at, last_opened_at, status, is_pinned
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)
            ON CONFLICT(book_id) DO UPDATE SET
                file_path = excluded.file_path,
                file_size = excluded.file_size,
                title = excluded.title,
                author = excluded.author,
                description = excluded.description,
                cover_path = excluded.cover_path,
                chapter_count = excluded.chapter_count,
                total_characters = excluded.total_characters,
                format = excluded.format,
                added_at = excluded.added_at,
                last_opened_at = excluded.last_opened_at,
                status = excluded.status,
                is_pinned = excluded.is_pinned",
            params![
                book.book_id,
                book.file_path,
                book.file_size,
                book.title,
                book.author,
                book.description,
                book.cover_path,
                book.chapter_count,
                book.total_characters,
                match book.format {
                    DbBookFormat::Epub => "epub",
                    DbBookFormat::Txt => "txt",
                    DbBookFormat::Pdf => "pdf",
                },
                book.added_at.timestamp(),
                book.last_opened_at.map(|d| d.timestamp()),
                match book.status {
                    DbBookStatus::Reading => "reading",
                    DbBookStatus::Completed => "completed",
                    DbBookStatus::Dropped => "dropped",
                    DbBookStatus::Planned => "planned",
                },
                book.is_pinned as i32,
            ],
        )?;
        Ok(())
    }

    pub fn get_all_books(&self) -> Result<Vec<DbBookRecord>> {
        let mut stmt = self.conn.prepare("SELECT books.* FROM books")?;
        let books = stmt
            .query_map([], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    pub fn get_book(&self, book_id: &str) -> Result<Option<DbBookRecord>> {
        let mut stmt = self
            .conn
            .prepare_cached("SELECT * FROM books WHERE book_id = ?1")?;
        let book = stmt
            .query_row([book_id], |row| self.row_to_book_record(row))
            .optional()?;
        Ok(book)
    }

    pub fn delete_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM books WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    pub fn search_books(&self, keyword: &str) -> Result<Vec<DbBookRecord>> {
        if keyword.trim().is_empty() {
            return Ok(Vec::new());
        }
        let escaped = keyword.replace('%', r"\%").replace('_', r"\_");
        let pattern = format!("%{}%", escaped);
        let mut stmt = self.conn.prepare(
            "SELECT * FROM books WHERE title LIKE ?1 ESCAPE '\\' OR author LIKE ?1 ESCAPE '\\' ORDER BY last_opened_at DESC NULLS LAST",
        )?;
        let books = stmt
            .query_map([&pattern], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    pub fn get_books_by_status(&self, status: &str) -> Result<Vec<DbBookRecord>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM books WHERE status = ?1 ORDER BY last_opened_at DESC NULLS LAST",
        )?;
        let books = stmt
            .query_map([status], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    pub fn get_pinned_books(&self) -> Result<Vec<DbBookRecord>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM books WHERE is_pinned = 1 ORDER BY last_opened_at DESC NULLS LAST",
        )?;
        let books = stmt
            .query_map([], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    pub fn get_recently_read_books(&self, limit: usize) -> Result<Vec<DbBookRecord>> {
        let mut stmt = self.conn.prepare(
            // 关联 reading_progress 表，使用 p.last_read_at 排序
            "SELECT b.* FROM books b
         JOIN reading_progress p ON b.book_id = p.book_id
         WHERE p.last_read_at IS NOT NULL
         ORDER BY p.last_read_at DESC
         LIMIT ?1",
        )?;
        let books = stmt
            .query_map([limit as i64], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    /// 分页获取书籍
    pub fn get_books_paginated(
        &self,
        limit: i64,
        offset: i64,
        sort_by: &str,
        sort_order: &str,
    ) -> Result<Vec<DbBookRecord>> {
        // 安全：仅允许白名单的排序列和方向
        let sort_column = match sort_by {
            "title" => "b.title",
            "added_at" => "b.added_at",
            "last_opened_at" => "b.last_opened_at",
            "file_size" => "b.file_size",
            _ => "b.added_at",
        };
        let order = if sort_order.eq_ignore_ascii_case("asc") { "ASC" } else { "DESC" };
        let sql = format!(
            "SELECT b.* FROM books b ORDER BY {} {} LIMIT ?1 OFFSET ?2",
            sort_column, order
        );
        let mut stmt = self.conn.prepare(&sql)?;
        let books = stmt
            .query_map(params![limit, offset], |row| self.row_to_book_record(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(books)
    }

    /// 更新书籍阅读状态
    pub fn update_book_status(&self, book_id: &str, status: &str) -> Result<()> {
        self.conn.execute(
            "UPDATE books SET status = ?1 WHERE book_id = ?2",
            params![status, book_id],
        )?;
        Ok(())
    }

    /// 更新书籍置顶状态
    pub fn update_book_pin(&self, book_id: &str, is_pinned: bool) -> Result<()> {
        self.conn.execute(
            "UPDATE books SET is_pinned = ?1 WHERE book_id = ?2",
            params![is_pinned as i32, book_id],
        )?;
        Ok(())
    }

    /// 获取书籍总数
    pub fn get_book_count(&self) -> Result<i64> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM books", [], |row| row.get(0))?;
        Ok(count)
    }

    // ==================== Reading Progress ====================

    pub fn save_progress(&self, progress: &DbReadingProgress) -> Result<()> {
        self.conn.execute(
            "INSERT INTO reading_progress (
                book_id, chapter_index, char_offset, page_index, total_pages,
                progress, reading_time_seconds, last_read_at, is_completed
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            ON CONFLICT(book_id) DO UPDATE SET
                chapter_index = excluded.chapter_index,
                char_offset = excluded.char_offset,
                page_index = excluded.page_index,
                total_pages = excluded.total_pages,
                progress = excluded.progress,
                reading_time_seconds = excluded.reading_time_seconds,
                last_read_at = excluded.last_read_at,
                is_completed = excluded.is_completed",
            params![
                progress.book_id,
                progress.chapter_index,
                progress.char_offset,
                progress.page_index,
                progress.total_pages,
                progress.progress,
                progress.reading_time_seconds,
                progress.last_read_at.timestamp(),
                progress.is_completed as i32,
            ],
        )?;
        Ok(())
    }

    pub fn delete_progress(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM reading_progress WHERE book_id = ?", [book_id])?;
        Ok(())
    }
    pub fn get_progress(&self, book_id: &str) -> Result<Option<DbReadingProgress>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM reading_progress WHERE book_id = ?1")?;
        let progress = stmt
            .query_row([book_id], |row| {
                Ok(DbReadingProgress {
                    book_id: row.get("book_id")?,
                    chapter_index: row.get("chapter_index")?,
                    char_offset: row.get("char_offset")?,
                    page_index: row.get("page_index")?,
                    total_pages: row.get("total_pages")?,
                    progress: row.get("progress")?,
                    reading_time_seconds: row.get("reading_time_seconds")?,
                    last_read_at: ts_to_dt(row.get("last_read_at")?),
                    is_completed: row.get::<_, i32>("is_completed")? != 0,
                })
            })
            .optional()?;
        Ok(progress)
    }

    // ==================== Bookmarks ====================

    fn row_to_bookmark(
        &self,
        row: &rusqlite::Row,
    ) -> std::result::Result<DbBookmark, rusqlite::Error> {
        Ok(DbBookmark {
            id: row.get("id")?,
            book_id: row.get("book_id")?,
            chapter_index: row.get("chapter_index")?,
            char_offset: row.get("char_offset")?,
            title: row.get("title")?,
            created_at: ts_to_dt(row.get("created_at")?),
        })
    }

    pub fn save_bookmark(&self, bookmark: &DbBookmark) -> Result<()> {
        self.conn.execute(
            "INSERT INTO bookmarks (id, book_id, chapter_index, char_offset, title, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(id) DO UPDATE SET
                book_id = excluded.book_id,
                chapter_index = excluded.chapter_index,
                char_offset = excluded.char_offset,
                title = excluded.title,
                created_at = excluded.created_at",
            params![
                bookmark.id,
                bookmark.book_id,
                bookmark.chapter_index,
                bookmark.char_offset,
                bookmark.title,
                bookmark.created_at.timestamp()
            ],
        )?;
        Ok(())
    }

    pub fn save_bookmarks_batch(&self, bookmarks: &[DbBookmark]) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;
        {
            let mut stmt = tx.prepare(
                "INSERT INTO bookmarks (id, book_id, chapter_index, char_offset, title, created_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)
                 ON CONFLICT(id) DO UPDATE SET
                    book_id = excluded.book_id,
                    chapter_index = excluded.chapter_index,
                    char_offset = excluded.char_offset,
                    title = excluded.title,
                    created_at = excluded.created_at",
            )?;
            for bookmark in bookmarks {
                stmt.execute(params![
                    bookmark.id,
                    bookmark.book_id,
                    bookmark.chapter_index,
                    bookmark.char_offset,
                    bookmark.title,
                    bookmark.created_at.timestamp()
                ])?;
            }
        }
        tx.commit()?;
        Ok(())
    }

    pub fn get_bookmarks(&self, book_id: &str) -> Result<Vec<DbBookmark>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM bookmarks WHERE book_id = ?1 ORDER BY chapter_index, char_offset",
        )?;
        let bookmarks = stmt
            .query_map([book_id], |row| self.row_to_bookmark(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(bookmarks)
    }
    pub fn get_bookmark_count(&self, book_id: &str) -> Result<i32> {
        // 使用 COUNT(*) 直接返回数量，无需加载所有列数据
        let count: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM bookmarks WHERE book_id = ?1",
            [book_id],
            |row| row.get(0),
        )?;

        Ok(count as i32)
    }

    pub fn delete_bookmark(&self, bookmark_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM bookmarks WHERE id = ?1", [bookmark_id])?;
        Ok(())
    }
    pub fn delete_bookmark_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM bookmarks WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    pub fn get_bookmark_by_id(&self, bookmark_id: &str) -> Result<Option<DbBookmark>> {
        let mut stmt = self.conn.prepare("SELECT * FROM bookmarks WHERE id = ?1")?;
        let bookmark = stmt
            .query_row([bookmark_id], |row| self.row_to_bookmark(row))
            .optional()?;
        Ok(bookmark)
    }

    // ==================== Notes ====================

    fn row_to_note(&self, row: &rusqlite::Row) -> std::result::Result<DbNote, rusqlite::Error> {
        Ok(DbNote {
            id: row.get("id")?,
            book_id: row.get("book_id")?,
            chapter_index: row.get("chapter_index")?,
            char_offset: row.get("char_offset")?,
            length: row.get("length")?,
            note_type: row
                .get::<_, String>("note_type")?
                .parse()
                .unwrap_or(DbNoteType::Annotation),
            content: row.get("content")?,
            selected_text: row.get("selected_text")?,
            highlight_color: row.get("highlight_color")?,
            created_at: ts_to_dt(row.get("created_at")?),
            updated_at: ts_to_dt(row.get("updated_at")?),
        })
    }
    pub fn save_note(&self, note: &DbNote) -> Result<()> {
        self.conn.execute(
            "INSERT INTO notes (id, book_id, chapter_index, char_offset, length, note_type, content, selected_text, highlight_color, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
             ON CONFLICT(id) DO UPDATE SET
                book_id = excluded.book_id,
                chapter_index = excluded.chapter_index,
                char_offset = excluded.char_offset,
                length = excluded.length,
                note_type = excluded.note_type,
                content = excluded.content,
                selected_text = excluded.selected_text,
                highlight_color = excluded.highlight_color,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at",
            params![note.id, note.book_id, note.chapter_index, note.char_offset, note.length, note.note_type.as_str(), note.content, note.selected_text, note.highlight_color, note.created_at.timestamp(), note.updated_at.timestamp()],
        )?;
        Ok(())
    }

    /// 批量保存笔记（使用事务保护）
    pub fn save_notes_batch(&self, notes: &[DbNote]) -> Result<()> {
        let tx = self.conn.unchecked_transaction()?;
        {
            let mut stmt = tx.prepare(
                "INSERT INTO notes (id, book_id, chapter_index, char_offset, length, note_type, content, selected_text, highlight_color, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
                 ON CONFLICT(id) DO UPDATE SET
                    book_id = excluded.book_id,
                    chapter_index = excluded.chapter_index,
                    char_offset = excluded.char_offset,
                    length = excluded.length,
                    note_type = excluded.note_type,
                    content = excluded.content,
                    selected_text = excluded.selected_text,
                    highlight_color = excluded.highlight_color,
                    created_at = excluded.created_at,
                    updated_at = excluded.updated_at",
            )?;
            for note in notes {
                stmt.execute(params![
                    note.id,
                    note.book_id,
                    note.chapter_index,
                    note.char_offset,
                    note.length,
                    note.note_type.as_str(),
                    note.content,
                    note.selected_text,
                    note.highlight_color,
                    note.created_at.timestamp(),
                    note.updated_at.timestamp()
                ])?;
            }
        }

        tx.commit()?;
        Ok(())
    }

    pub fn get_notes(&self, book_id: &str) -> Result<Vec<DbNote>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM notes WHERE book_id = ?1 ORDER BY chapter_index, char_offset",
        )?;
        let notes = stmt
            .query_map([book_id], |row| self.row_to_note(row))?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(notes)
    }
    pub fn get_note_stats(&self, book_id: &str) -> Result<NoteStats> {
        // 使用聚合查询，一次性获取所有统计值
        // 利用 idx_notes_type 索引加速
        let stats = self.conn().query_row(
            r#"
            SELECT
                COUNT(*) as total,
                SUM(CASE WHEN note_type = 'highlight' THEN 1 ELSE 0 END) as highlights,
                SUM(CASE WHEN note_type = 'annotation' THEN 1 ELSE 0 END) as annotations
            FROM notes
            WHERE book_id = ?1
            "#,
            [book_id],
            |row| {
                let total: i64 = row.get("total")?;
                let highlights: Option<i64> = row.get("highlights")?;
                let annotations: Option<i64> = row.get("annotations")?;
                Ok(NoteStats {
                    total_count: total as i32,
                    highlight_count: highlights.unwrap_or(0) as i32,
                    annotation_count: annotations.unwrap_or(0) as i32,
                })
            },
        )?;

        Ok(stats)
    }
    pub fn get_notes_by_type(&self, book_id: &str, note_type: DbNoteType) -> Result<Vec<DbNote>> {
        let mut stmt = self.conn.prepare("SELECT * FROM notes WHERE book_id = ?1 AND note_type = ?2 ORDER BY chapter_index, char_offset")?;
        let notes = stmt
            .query_map(params![book_id, note_type.as_str()], |row| {
                self.row_to_note(row)
            })?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(notes)
    }

    pub fn get_note_by_id(&self, note_id: &str) -> Result<Option<DbNote>> {
        let mut stmt = self.conn.prepare("SELECT * FROM notes WHERE id = ?1")?;
        let note = stmt
            .query_row([note_id], |row| self.row_to_note(row))
            .optional()?;
        Ok(note)
    }

    pub fn delete_note(&self, note_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM notes WHERE id = ?1", [note_id])?;
        Ok(())
    }

    pub fn delete_notes_by_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM notes WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    // ==================== Reading Sessions ====================

    pub fn save_session(&self, session: &DbReadingSession) -> Result<()> {
        self.conn.execute(
            "INSERT INTO reading_sessions (id, book_id, chapter_index, start_char_offset, end_char_offset, started_at, ended_at, duration_seconds, characters_read)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
             ON CONFLICT(id) DO UPDATE SET
                book_id = excluded.book_id,
                chapter_index = excluded.chapter_index,
                start_char_offset = excluded.start_char_offset,
                end_char_offset = excluded.end_char_offset,
                started_at = excluded.started_at,
                ended_at = excluded.ended_at,
                duration_seconds = excluded.duration_seconds,
                characters_read = excluded.characters_read",
            params![session.id, session.book_id, session.chapter_index, session.start_char_offset, session.end_char_offset, session.started_at.timestamp(), session.ended_at.timestamp(), session.duration_seconds, session.characters_read],
        )?;
        Ok(())
    }

    pub fn get_sessions(&self, book_id: &str) -> Result<Vec<DbReadingSession>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM reading_sessions WHERE book_id = ?1 ORDER BY started_at DESC",
        )?;
        let sessions = stmt
            .query_map([book_id], row_to_reading_session)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(sessions)
    }

    pub fn get_sessions_by_book(
        &self,
        book_id: &str,
        limit: usize,
    ) -> Result<Vec<DbReadingSession>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM reading_sessions WHERE book_id = ?1 ORDER BY started_at DESC LIMIT ?2",
        )?;
        let sessions = stmt
            .query_map(params![book_id, limit as i64], row_to_reading_session)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(sessions)
    }

    pub fn get_sessions_by_date_range(
        &self,
        book_id: &str,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<DbReadingSession>> {
        let mut stmt = self.conn.prepare(
            "SELECT * FROM reading_sessions
             WHERE book_id = ?1 AND date(started_at, 'unixepoch') BETWEEN ?2 AND ?3
             ORDER BY started_at DESC",
        )?;
        let sessions = stmt
            .query_map(
                params![book_id, start_date, end_date],
                row_to_reading_session,
            )?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(sessions)
    }

    pub fn get_recent_sessions(&self, limit: usize) -> Result<Vec<DbReadingSession>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM reading_sessions ORDER BY started_at DESC LIMIT ?1")?;
        let sessions = stmt
            .query_map([limit as i64], row_to_reading_session)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(sessions)
    }

    pub fn delete_sessions_by_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM reading_sessions WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    pub fn delete_daily_read_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM daily_read_books WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    // ==================== DbChapters ====================

    pub fn save_chapters(&self, book_id: &str, chapters: &[DbChapter]) -> Result<()> {
        if chapters.is_empty() {
            return Ok(());
        }

        let tx = self.conn.unchecked_transaction()?;
        {
            // 预编译语句，循环复用
            let mut stmt = tx.prepare(
                "INSERT INTO chapters (id, book_id, title, content_file, chapter_index, word_count, cached_at, level)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
                 ON CONFLICT(id) DO UPDATE SET
                    book_id = excluded.book_id,
                    title = excluded.title,
                    content_file = excluded.content_file,
                    chapter_index = excluded.chapter_index,
                    word_count = excluded.word_count,
                    cached_at = excluded.cached_at,
                    level = excluded.level",
            )?;

            for chapter in chapters {
                // ✅ 校验：确保章节的 book_id 与参数一致
                if chapter.book_id != book_id {
                    anyhow::bail!(
                        "Chapter ID {} belongs to book {}, but expected book {}",
                        chapter.id,
                        chapter.book_id,
                        book_id
                    );
                }

                stmt.execute(params![
                    chapter.id,
                    chapter.book_id,
                    chapter.title,
                    chapter.content_file,
                    chapter.chapter_index,
                    chapter.word_count,
                    chapter.cached_at.timestamp(),
                    chapter.level,
                ])?;
            }
        } // stmt 在此析构

        tx.commit()?;
        Ok(())
    }

    pub fn get_chapters_by_book(&self, book_id: &str) -> Result<Vec<DbChapter>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM chapters WHERE book_id = ?1 ORDER BY chapter_index")?;
        let chapters = stmt
            .query_map([book_id], row_to_chapter)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(chapters)
    }

    pub fn get_chapter_by_index(
        &self,
        book_id: &str,
        chapter_index: i32,
    ) -> Result<Option<DbChapter>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM chapters WHERE book_id = ?1 AND chapter_index = ?2")?;
        let chapter = stmt
            .query_row(rusqlite::params![book_id, chapter_index], row_to_chapter)
            .optional()?;
        Ok(chapter)
    }

    pub fn delete_chapters_by_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM chapters WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    // ==================== Categories ====================

    pub fn save_category(&self, category: &DbBookCategory) -> Result<()> {
        self.conn.execute(
            "INSERT INTO categories (id, name, description, color, sort_order, created_at, is_system, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                color = excluded.color,
                sort_order = excluded.sort_order,
                created_at = excluded.created_at,
                is_system = excluded.is_system,
                updated_at = excluded.updated_at",
            params![category.id, category.name, category.description, category.color, category.sort_order, category.created_at.timestamp(), category.is_system as i32, category.updated_at.timestamp()],
        )?;
        Ok(())
    }

    pub fn get_category_by_id(&self, category_id: &str) -> Result<Option<DbBookCategory>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM categories WHERE id = ?1")?;
        let category = stmt
            .query_row([category_id], row_to_book_category)
            .optional()?;
        Ok(category)
    }

    pub fn get_all_categories(&self) -> Result<Vec<DbBookCategory>> {
        let mut stmt = self
            .conn
            .prepare("SELECT * FROM categories ORDER BY sort_order")?;
        let categories = stmt
            .query_map([], row_to_book_category)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(categories)
    }

    pub fn delete_category(&self, category_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM categories WHERE id = ?1", [category_id])?;
        Ok(())
    }

    pub fn assign_category(&self, book_id: &str, category_id: &str) -> Result<()> {
        self.conn.execute(
            "INSERT INTO book_categories (book_id, category_id)
         VALUES (?1, ?2)
         ON CONFLICT(book_id, category_id)
         DO UPDATE SET book_id = excluded.book_id",
            params![book_id, category_id],
        )?;
        Ok(())
    }

    pub fn remove_category(&self, book_id: &str, category_id: &str) -> Result<()> {
        self.conn.execute(
            "DELETE FROM book_categories WHERE book_id = ?1 AND category_id = ?2",
            params![book_id, category_id],
        )?;
        Ok(())
    }

    pub fn get_categories_for_book(&self, book_id: &str) -> Result<Vec<DbBookCategory>> {
        let mut stmt = self.conn.prepare(
            "SELECT c.* FROM categories c INNER JOIN book_categories bc ON c.id = bc.category_id WHERE bc.book_id = ?1 ORDER BY c.sort_order",
        )?;
        let categories = stmt
            .query_map([book_id], row_to_book_category)?
            .collect::<Result<Vec<_>, _>>()?;
        Ok(categories)
    }

    pub fn clear_categories_for_book(&self, book_id: &str) -> Result<()> {
        self.conn
            .execute("DELETE FROM book_categories WHERE book_id = ?1", [book_id])?;
        Ok(())
    }

    pub fn set_categories_for_book(&self, book_id: &str, category_ids: &[String]) -> Result<()> {
        // 使用 rusqlite 的事务 API，利用 RAII 自动处理回滚
        let tx = self.conn.unchecked_transaction()?;

        // 1. 清除该书现有的所有分类关联
        tx.execute("DELETE FROM book_categories WHERE book_id = ?1", [book_id])?;
        {
            let mut stmt = tx.prepare(
                r#"
            INSERT INTO book_categories (book_id, category_id)
            VALUES (?1, ?2)
            ON CONFLICT(book_id, category_id)
            DO UPDATE SET book_id = excluded.book_id
            "#,
            )?;

            for category_id in category_ids {
                stmt.execute(rusqlite::params![book_id, category_id])?;
            }
        }
        tx.commit()?;

        Ok(())
    }

    // ==================== Stats ====================

    pub fn get_daily_stats(&self, date: &str) -> Result<Option<DbDailyReadingStats>> {
        // 从 reading_sessions 实时聚合基础统计
        let sessions_agg = self.conn.query_row(
            "SELECT
                COALESCE(COUNT(*), 0) as session_count,
                COALESCE(SUM(duration_seconds), 0) as total_time,
                COALESCE(SUM(characters_read), 0) as total_chars
             FROM reading_sessions
             WHERE date(started_at, 'unixepoch') = ?1",
            [date],
            |row| {
                Ok((
                    row.get::<_, i32>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            },
        ).optional()?;

        let (session_count, total_time, total_chars) = match sessions_agg {
            Some(s) => s,
            None => (0, 0, 0),
        };

        // 从 daily_stats 缓存读取 Flutter 侧计算的扩展字段
        let (chapters_read, pages_read) = self
            .conn
            .query_row(
                "SELECT chapters_read, pages_read FROM daily_stats WHERE date = ?1",
                [date],
                |row| Ok((row.get::<_, i32>(0)?, row.get::<_, i32>(1)?)),
            )
            .optional()?
            .unwrap_or((0, 0));

        let books_read = self.get_books_for_date(date)?;

        if session_count == 0 && chapters_read == 0 && pages_read == 0 && books_read.is_empty() {
            return Ok(None);
        }

        Ok(Some(DbDailyReadingStats {
            date: date.to_string(),
            total_reading_time_seconds: total_time,
            total_characters_read: total_chars,
            books_read,
            session_count,
            chapters_read,
            pages_read,
        }))
    }

    fn get_books_for_date(&self, date: &str) -> Result<Vec<String>> {
        let mut stmt = self
            .conn
            .prepare("SELECT book_id FROM daily_read_books WHERE date = ?1")?;
        let books = stmt
            .query_map([date], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;
        Ok(books)
    }

    fn save_books_for_date(&self, date: &str, book_ids: &[String]) -> Result<()> {
        self.conn.execute(
            "DELETE FROM daily_read_books WHERE date = ?1",
            [date],
        )?;
        for book_id in book_ids {
            self.conn.execute(
                "INSERT OR IGNORE INTO daily_read_books (date, book_id) VALUES (?1, ?2)",
                params![date, book_id],
            )?;
        }
        Ok(())
    }

    pub fn update_daily_stats(&self, stats: &DbDailyReadingStats) -> Result<()> {
        self.conn.execute(
            "INSERT INTO daily_stats (date, reading_time_seconds, characters_read, session_count, chapters_read, pages_read)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(date) DO UPDATE SET
                reading_time_seconds = excluded.reading_time_seconds,
                characters_read = excluded.characters_read,
                session_count = excluded.session_count,
                chapters_read = excluded.chapters_read,
                pages_read = excluded.pages_read",
            params![stats.date.to_string(), stats.total_reading_time_seconds, stats.total_characters_read, stats.session_count, stats.chapters_read, stats.pages_read],
        )?;
        self.save_books_for_date(&stats.date, &stats.books_read)?;
        Ok(())
    }

    pub fn get_global_stats(&self) -> Result<DbGlobalStats> {
        // 始终从 reading_sessions 实时聚合，保证所有动态值准确
        let stats = self.conn.query_row(
            r#"
        SELECT
            COALESCE(SUM(duration_seconds), 0) as total_time,
            COALESCE(SUM(characters_read), 0) as total_chars,
            (SELECT COUNT(DISTINCT book_id) FROM reading_sessions) as books_read,
            (SELECT COUNT(*) FROM reading_progress WHERE is_completed = 1) as books_completed,
            (SELECT COUNT(*) FROM books) as total_books,
            (SELECT COUNT(*) FROM notes) as total_notes,
            (SELECT COUNT(*) FROM bookmarks) as total_bookmarks
        FROM reading_sessions
        "#,
            [],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, i32>(2)?,
                    row.get::<_, i32>(3)?,
                    row.get::<_, i32>(4)?,
                    row.get::<_, i32>(5)?,
                    row.get::<_, i32>(6)?,
                ))
            },
        )?;

        let (
            total_time,
            total_chars,
            books_read,
            books_completed,
            total_books,
            total_notes,
            total_bookmarks,
        ) = stats;

        let today = chrono::Utc::now().date_naive().to_string();
        let (today_time, today_chars) = self
            .conn
            .query_row(
                "SELECT COALESCE(SUM(duration_seconds), 0), COALESCE(SUM(characters_read), 0)
         FROM reading_sessions WHERE date(started_at, 'unixepoch') = ?1",
                [&today],
                |row| Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?)),
            )
            .optional()?
            .unwrap_or((0, 0));

        let avg_speed = if total_time > 0 {
            (total_chars as f64 / total_time as f64 * 60.0) as f32
        } else {
            0.0
        };

        let consecutive_days = self.calculate_consecutive_reading_days()?;

        Ok(DbGlobalStats {
            total_reading_time_seconds: total_time,
            total_characters_read: total_chars,
            books_read_count: books_read,
            books_completed_count: books_completed,
            consecutive_reading_days: consecutive_days,
            today_reading_time_seconds: today_time,
            today_characters_read: today_chars,
            average_reading_speed: avg_speed,
            total_books_count: total_books,
            total_notes_count: total_notes,
            total_bookmarks_count: total_bookmarks,
            max_consecutive_reading_days: consecutive_days,
        })
    }
    fn calculate_consecutive_reading_days(&self) -> Result<i32> {
        // 优化：只查询最近 365 天的数据，避免加载全量历史记录
        let mut stmt = self.conn.prepare(
            "SELECT DISTINCT date(started_at, 'unixepoch') FROM reading_sessions
             WHERE duration_seconds > 0
               AND date(started_at, 'unixepoch') >= date('now', '-365 days')
             ORDER BY date(started_at, 'unixepoch') DESC",
        )?;

        // 将结果收集到 Vec<String> 中
        let recorded_dates: Vec<String> = stmt
            .query_map([], |row| row.get(0))?
            .collect::<Result<Vec<_>, _>>()?;

        // 如果没有记录，直接返回 0
        if recorded_dates.is_empty() {
            return Ok(0);
        }

        // 为了快速查找，将 Vec 转换为 HashSet
        // HashSet 的查找复杂度是 O(1)，而 Vec 的 contains 是 O(N)
        use std::collections::HashSet;
        let date_set: HashSet<String> = recorded_dates.into_iter().collect();

        // 从"今天"开始向前推算
        let mut days = 0;
        let mut current_date = chrono::Utc::now().date_naive();

        loop {
            let date_str = current_date.to_string(); // 格式通常为 "YYYY-MM-DD"，需确保与数据库中存储格式一致

            // 检查这一天是否有记录
            if date_set.contains(&date_str) {
                days += 1;
                // 向前推一天
                // pred_opt() 在日期为最小值时返回 None，避免溢出
                match current_date.pred_opt() {
                    Some(prev_date) => current_date = prev_date,
                    None => break, // 已经追溯到时间起点，不可能再连续了
                }
            } else {
                // 中断了，退出循环
                break;
            }
        }

        Ok(days)
    }
    pub fn get_daily_stats_range(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> Result<Vec<DbDailyReadingStats>> {
        // 从 reading_sessions 按天聚合基础统计
        let mut stmt = self.conn.prepare(
            "SELECT
                date(started_at, 'unixepoch') as date,
                COALESCE(COUNT(*), 0) as session_count,
                COALESCE(SUM(duration_seconds), 0) as total_time,
                COALESCE(SUM(characters_read), 0) as total_chars
             FROM reading_sessions
             WHERE date(started_at, 'unixepoch') >= ?1 AND date(started_at, 'unixepoch') <= ?2
             GROUP BY date(started_at, 'unixepoch')
             ORDER BY date ASC"
        )?;

        let mut session_map: std::collections::HashMap<String, (i32, i64, i64)> = stmt
            .query_map(params![start_date, end_date], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, i32>(1)?,
                    row.get::<_, i64>(2)?,
                    row.get::<_, i64>(3)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .map(|(date, sessions, time, chars)| (date, (sessions, time, chars)))
            .collect();

        // 从 daily_stats 缓存读取扩展字段
        let mut stats_stmt = self.conn.prepare(
            "SELECT date, chapters_read, pages_read FROM daily_stats
             WHERE date >= ?1 AND date <= ?2"
        )?;
        let cache_map: std::collections::HashMap<String, (i32, i32)> = stats_stmt
            .query_map(params![start_date, end_date], |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, i32>(1)?,
                    row.get::<_, i32>(2)?,
                ))
            })?
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .map(|(date, chapters, pages)| (date, (chapters, pages)))
            .collect();

        // 合并日期范围中的所有天
        let start = chrono::NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
            .context("Invalid start_date format")?;
        let end = chrono::NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
            .context("Invalid end_date format")?;

        let mut results = Vec::new();
        let mut current = start;
        while current <= end {
            let date_str = current.to_string();
            let (sessions, time, chars) = session_map.remove(&date_str).unwrap_or((0, 0, 0));
            let (chapters, pages) = cache_map.get(&date_str).copied().unwrap_or((0, 0));
            let books = self.get_books_for_date(&date_str)?;

            if sessions > 0 || chapters > 0 || pages > 0 || !books.is_empty() {
                results.push(DbDailyReadingStats {
                    date: date_str,
                    total_reading_time_seconds: time,
                    total_characters_read: chars,
                    books_read: books,
                    session_count: sessions,
                    chapters_read: chapters,
                    pages_read: pages,
                });
            }
            current = current.succ_opt().unwrap_or(current);
        }

        Ok(results)
    }
    // 在应用生命周期结束时主动执行完整检查点
    pub fn full_checkpoint(&self) -> Result<()> {
        self.conn
            .pragma_update(None, "wal_checkpoint", "TRUNCATE")?;
        Ok(())
    }
}

impl Drop for Database {
    fn drop(&mut self) {
        // 使用 PASSIVE 模式，不会阻塞
        if let Err(e) = self.conn.pragma_update(None, "wal_checkpoint", "PASSIVE") {
            tracing::debug!("WAL checkpoint failed during drop: {}", e);
        }
    }
}
