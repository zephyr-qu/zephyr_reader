//! SQLite 持久化存储实现
//!
//! 使用 rusqlite 提供基于 SQLite 的进度和书签持久化存储。
//! 与 Flutter 侧的 Drift 数据库结构保持一致。
//! 集成 LRU 缓存减少数据库访问，提升读取性能。

use crate::ffi::{Bookmark, CachedLayout, LayoutCacheResult, PageOffset, ReadingProgress};
use crate::storage::lru_cache::{CacheStats, LruCache};
use crate::storage::{ProgressStorage, StorageError, StorageResult};
use rusqlite::{Connection, OptionalExtension};
use serde_json;
use std::path::Path;
use std::sync::Mutex;

/// SQLite 存储实现
///
/// 将阅读进度和书签持久化到 SQLite 数据库，应用重启后数据保留。
/// 数据库结构与 Flutter 侧的 Drift 数据库保持一致。
///
/// # 数据库结构
///
/// - `reading_progress` 表：存储阅读进度
/// - `bookmarks` 表：存储书签
/// - `layout_cache` 表：存储排版缓存
///
/// # LRU 缓存
///
/// 内置 LRU 缓存用于缓存频繁访问的阅读进度和书签数据，
/// 减少数据库查询次数，提升读取性能。
pub struct SqliteStorage {
    conn: Mutex<Connection>,
    /// 阅读进度 LRU 缓存
    progress_cache: Mutex<LruCache<String, ReadingProgress>>,
    /// 书签 LRU 缓存
    bookmark_cache: Mutex<LruCache<String, Vec<Bookmark>>>,
}

impl SqliteStorage {
    /// 创建新的 SQLite 存储
    ///
    /// # 参数
    ///
    /// * `db_path` - 数据库文件路径
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// use rust_lib_zephyr_reader::storage::SqliteStorage;
    ///
    /// let storage = SqliteStorage::new("/path/to/app.db")?;
    /// # Ok::<(), Box<dyn std::error::Error>>(())
    /// ```
    pub fn new<P: AsRef<Path>>(db_path: P) -> StorageResult<Self> {
        Self::new_with_cache(db_path, 100, 50 * 1024 * 1024)
    }

    /// 创建带 LRU 缓存的 SQLite 存储
    ///
    /// # 参数
    ///
    /// * `db_path` - 数据库文件路径
    /// * `max_entries` - LRU 缓存最大条目数
    /// * `max_memory_bytes` - LRU 缓存最大内存占用（字节）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// use rust_lib_zephyr_reader::storage::SqliteStorage;
    ///
    /// // 创建缓存：最大 100 条目，最大内存 50MB
    /// let storage = SqliteStorage::new_with_cache("/path/to/app.db", 100, 50 * 1024 * 1024)?;
    /// # Ok::<(), Box<dyn std::error::Error>>(())
    /// ```
    pub fn new_with_cache<P: AsRef<Path>>(
        db_path: P,
        max_entries: usize,
        max_memory_bytes: usize,
    ) -> StorageResult<Self> {
        let conn =
            Connection::open(db_path).map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let storage = Self {
            conn: Mutex::new(conn),
            progress_cache: Mutex::new(LruCache::new(max_entries, max_memory_bytes / 2)),
            bookmark_cache: Mutex::new(LruCache::new(max_entries, max_memory_bytes / 2)),
        };

        // 初始化数据库表
        storage.init_tables()?;

        Ok(storage)
    }

    /// 获取缓存统计信息
    ///
    /// # 返回值
    ///
    /// 返回进度缓存和书签缓存的统计信息
    pub fn get_cache_stats(&self) -> (CacheStats, CacheStats) {
        let progress_stats = {
            let cache = self
                .progress_cache
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            cache.get_stats()
        };

        let bookmark_stats = {
            let cache = self
                .bookmark_cache
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            cache.get_stats()
        };

        (progress_stats, bookmark_stats)
    }

    /// 清除所有缓存
    ///
    /// 清除进度缓存和书签缓存中的所有数据
    pub fn clear_all_cache(&self) {
        {
            let mut cache = self
                .progress_cache
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            cache.clear();
        }
        {
            let mut cache = self
                .bookmark_cache
                .lock()
                .unwrap_or_else(|e| e.into_inner());
            cache.clear();
        }
        tracing::info!("SQLite 存储缓存已清除");
    }

    /// 获取数据库连接（带错误处理）
    fn get_conn(&self) -> StorageResult<std::sync::MutexGuard<'_, Connection>> {
        self.conn
            .lock()
            .map_err(|e| StorageError::DatabaseError(format!("锁定数据库连接失败：{}", e)))
    }

    /// 初始化数据库表结构
    fn init_tables(&self) -> StorageResult<()> {
        let conn = self.get_conn()?;

        // 阅读进度表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS reading_progress (
                book_id TEXT PRIMARY KEY NOT NULL,
                chapter_id INTEGER NOT NULL,
                page_index INTEGER NOT NULL,
                total_pages INTEGER NOT NULL,
                progress REAL NOT NULL,
                reading_time_seconds INTEGER NOT NULL DEFAULT 0,
                last_read_timestamp INTEGER NOT NULL
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 书签表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS bookmarks (
                bookmark_id TEXT PRIMARY KEY NOT NULL,
                book_id TEXT NOT NULL,
                chapter_id INTEGER NOT NULL,
                page_index INTEGER NOT NULL,
                title TEXT NOT NULL,
                created_timestamp INTEGER NOT NULL,
                note TEXT
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 阅读统计表（累计数据）
        conn.execute(
            "CREATE TABLE IF NOT EXISTS reading_stats (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                total_reading_time_seconds INTEGER NOT NULL DEFAULT 0,
                total_characters_read INTEGER NOT NULL DEFAULT 0,
                books_read_count INTEGER NOT NULL DEFAULT 0,
                books_completed_count INTEGER NOT NULL DEFAULT 0,
                last_read_date TEXT,
                consecutive_reading_days INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 初始化统计表（如果不存在）
        conn.execute("INSERT OR IGNORE INTO reading_stats (id) VALUES (1)", [])
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 每日阅读记录表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS daily_reading_records (
                date TEXT PRIMARY KEY NOT NULL,
                reading_time_seconds INTEGER NOT NULL DEFAULT 0,
                characters_read INTEGER NOT NULL DEFAULT 0,
                chapters_read INTEGER NOT NULL DEFAULT 0,
                pages_read INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 阅读会话记录表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS reading_sessions (
                session_id TEXT PRIMARY KEY NOT NULL,
                book_id TEXT NOT NULL,
                chapter_id INTEGER NOT NULL,
                start_timestamp INTEGER NOT NULL,
                end_timestamp INTEGER NOT NULL,
                duration_seconds INTEGER NOT NULL,
                characters_read INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 创建索引
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_bookmarks_book_id ON bookmarks(book_id)",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sessions_book_id ON reading_sessions(book_id)",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_sessions_date ON reading_sessions(end_timestamp)",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 排版缓存表
        conn.execute(
            "CREATE TABLE IF NOT EXISTS layout_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id TEXT NOT NULL,
                chapter_id INTEGER NOT NULL,
                config_hash TEXT NOT NULL,
                page_offsets TEXT NOT NULL,
                total_pages INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                UNIQUE(book_id, chapter_id, config_hash)
            )",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 创建索引加速查询
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_layout_cache_lookup ON layout_cache(book_id, chapter_id, config_hash)",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(())
    }
}

impl ProgressStorage for SqliteStorage {
    fn save_progress(&self, book_id: &str, progress: &ReadingProgress) -> StorageResult<()> {
        let conn = self.get_conn()?;

        conn.execute(
            "INSERT INTO reading_progress
             (book_id, chapter_id, page_index, total_pages, progress, reading_time_seconds, last_read_timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(book_id) DO UPDATE SET
             chapter_id = excluded.chapter_id,
             page_index = excluded.page_index,
             total_pages = excluded.total_pages,
             progress = excluded.progress,
             reading_time_seconds = excluded.reading_time_seconds,
             last_read_timestamp = excluded.last_read_timestamp",
            [
                book_id,
                &progress.chapter_id.to_string(),
                &progress.page_index.to_string(),
                &progress.total_pages.to_string(),
                &progress.progress.to_string(),
                &progress.reading_time_seconds.to_string(),
                &progress.last_read_timestamp.to_string(),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 更新缓存
        {
            let mut cache = self
                .progress_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            cache.insert(book_id.to_string(), progress.clone());
        }

        Ok(())
    }

    fn load_progress(&self, book_id: &str) -> StorageResult<Option<ReadingProgress>> {
        // 先查缓存
        {
            let mut cache = self
                .progress_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            if let Some(progress) = cache.get_mut(&book_id.to_string()) {
                tracing::trace!("进度缓存命中：{}", book_id);
                return Ok(Some(progress.clone()));
            }
        }

        // 缓存未命中，查询数据库
        let conn = self.get_conn()?;
        tracing::trace!("进度缓存未命中，查询数据库：{}", book_id);

        let result = conn
            .query_row(
                "SELECT chapter_id, page_index, total_pages, progress,
                        reading_time_seconds, last_read_timestamp
                 FROM reading_progress
                 WHERE book_id = ?1",
                [book_id],
                |row| {
                    Ok(ReadingProgress {
                        chapter_id: row.get(0)?,
                        page_index: row.get(1)?,
                        total_pages: row.get(2)?,
                        progress: row.get(3)?,
                        reading_time_seconds: row.get(4)?,
                        last_read_timestamp: row.get(5)?,
                    })
                },
            )
            .optional()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 写入缓存
        if let Some(ref progress) = result {
            let mut cache = self
                .progress_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            cache.insert(book_id.to_string(), progress.clone());
        }

        Ok(result)
    }

    fn delete_progress(&self, book_id: &str) -> StorageResult<()> {
        let conn = self.get_conn()?;

        conn.execute("DELETE FROM reading_progress WHERE book_id = ?1", [book_id])
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 清除缓存
        {
            let mut cache = self
                .progress_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            cache.remove(&book_id.to_string());
        }

        Ok(())
    }

    fn get_all_progress(&self) -> StorageResult<Vec<(String, ReadingProgress)>> {
        let conn = self.get_conn()?;

        let mut stmt = conn
            .prepare(
                "SELECT book_id, chapter_id, page_index, total_pages, progress,
                        reading_time_seconds, last_read_timestamp
                 FROM reading_progress
                 ORDER BY last_read_timestamp DESC",
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let progress_list = stmt
            .query_map([], |row| {
                let book_id: String = row.get(0)?;
                let progress = ReadingProgress {
                    chapter_id: row.get(1)?,
                    page_index: row.get(2)?,
                    total_pages: row.get(3)?,
                    progress: row.get(4)?,
                    reading_time_seconds: row.get(5)?,
                    last_read_timestamp: row.get(6)?,
                };
                Ok((book_id, progress))
            })
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(progress_list)
    }

    fn save_bookmark(&self, book_id: &str, bookmark: &Bookmark) -> StorageResult<()> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        conn.execute(
            "INSERT INTO bookmarks
             (bookmark_id, book_id, chapter_id, page_index, title, created_timestamp, note)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(bookmark_id) DO UPDATE SET
             chapter_id = excluded.chapter_id,
             page_index = excluded.page_index,
             title = excluded.title,
             note = excluded.note",
            [
                &bookmark.bookmark_id,
                book_id,
                &bookmark.chapter_id.to_string(),
                &bookmark.page_index.to_string(),
                &bookmark.title,
                &bookmark.created_timestamp.to_string(),
                bookmark.note.as_deref().unwrap_or(""),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 使缓存失效（下次读取时会重新加载）
        {
            let mut cache = self
                .bookmark_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            cache.remove(&book_id.to_string());
        }

        Ok(())
    }

    fn load_bookmarks(&self, book_id: &str) -> StorageResult<Vec<Bookmark>> {
        // 先查缓存
        {
            let mut cache = self
                .bookmark_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            if let Some(bookmarks) = cache.get_mut(&book_id.to_string()) {
                tracing::trace!("书签缓存命中：{}", book_id);
                return Ok(bookmarks.clone());
            }
        }

        // 缓存未命中，查询数据库
        tracing::trace!("书签缓存未命中，查询数据库：{}", book_id);
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let mut stmt = conn
            .prepare(
                "SELECT bookmark_id, book_id, chapter_id, page_index, title,
                        created_timestamp, note
                 FROM bookmarks
                 WHERE book_id = ?1
                 ORDER BY created_timestamp ASC",
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let bookmarks = stmt
            .query_map([book_id], |row| {
                let note: Option<String> = row.get(6)?;
                Ok(Bookmark {
                    bookmark_id: row.get(0)?,
                    book_id: row.get(1)?,
                    chapter_id: row.get(2)?,
                    page_index: row.get(3)?,
                    title: row.get(4)?,
                    created_timestamp: row.get(5)?,
                    note: if note.as_deref().unwrap_or("").is_empty() {
                        None
                    } else {
                        note
                    },
                })
            })
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 写入缓存
        {
            let mut cache = self
                .bookmark_cache
                .lock()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            cache.insert(book_id.to_string(), bookmarks.clone());
        }

        Ok(bookmarks)
    }

    fn delete_bookmark(&self, _book_id: &str, bookmark_id: &str) -> StorageResult<bool> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let affected = conn
            .execute(
                "DELETE FROM bookmarks WHERE bookmark_id = ?1",
                [bookmark_id],
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(affected > 0)
    }

    fn clear_bookmarks(&self, book_id: &str) -> StorageResult<usize> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let affected = conn
            .execute("DELETE FROM bookmarks WHERE book_id = ?1", [book_id])
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(affected)
    }

    fn get_all_bookmarks(&self) -> StorageResult<Vec<Bookmark>> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let mut stmt = conn
            .prepare(
                "SELECT bookmark_id, book_id, chapter_id, page_index, title,
                        created_timestamp, note
                 FROM bookmarks
                 ORDER BY created_timestamp DESC",
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let bookmarks = stmt
            .query_map([], |row| {
                let note: Option<String> = row.get(6)?;
                Ok(Bookmark {
                    bookmark_id: row.get(0)?,
                    book_id: row.get(1)?,
                    chapter_id: row.get(2)?,
                    page_index: row.get(3)?,
                    title: row.get(4)?,
                    created_timestamp: row.get(5)?,
                    note: if note.as_deref().unwrap_or("").is_empty() {
                        None
                    } else {
                        note
                    },
                })
            })
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(bookmarks)
    }
}

/// 阅读统计扩展方法
impl SqliteStorage {
    /// 记录阅读会话
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    /// * `chapter_id` - 章节 ID
    /// * `duration_seconds` - 阅读时长（秒）
    /// * `characters_read` - 阅读字数
    pub fn record_reading_session(
        &self,
        book_id: &str,
        chapter_id: i32,
        duration_seconds: i64,
        characters_read: i64,
    ) -> StorageResult<()> {
        let mut conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;

        let session_id = uuid::Uuid::new_v4().to_string();
        let start_timestamp = now - duration_seconds;
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();

        // 开始事务
        let tx = conn
            .transaction()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 1. 记录会话
        tx.execute(
            "INSERT INTO reading_sessions 
             (session_id, book_id, chapter_id, start_timestamp, end_timestamp, duration_seconds, characters_read)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            [
                &session_id,
                book_id,
                &chapter_id.to_string(),
                &start_timestamp.to_string(),
                &now.to_string(),
                &duration_seconds.to_string(),
                &characters_read.to_string(),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 2. 更新每日记录
        tx.execute(
            "INSERT INTO daily_reading_records 
             (date, reading_time_seconds, characters_read, chapters_read, pages_read)
             VALUES (?1, ?2, ?3, 0, 0)
             ON CONFLICT(date) DO UPDATE SET
             reading_time_seconds = reading_time_seconds + excluded.reading_time_seconds,
             characters_read = characters_read + excluded.characters_read",
            [
                &today,
                &duration_seconds.to_string(),
                &characters_read.to_string(),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        // 3. 检查是否新的一天，更新连续阅读天数
        let last_read_date: Option<String> = tx
            .query_row(
                "SELECT last_read_date FROM reading_stats WHERE id = 1",
                [],
                |row| row.get(0),
            )
            .optional()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let yesterday = (chrono::Local::now() - chrono::Duration::days(1))
            .format("%Y-%m-%d")
            .to_string();

        let consecutive_days: i32 = if let Some(last_date) = last_read_date {
            if last_date == today {
                // 同一天，保持连续天数不变
                tx.query_row(
                    "SELECT consecutive_reading_days FROM reading_stats WHERE id = 1",
                    [],
                    |row| row.get(0),
                )
                .unwrap_or(1)
            } else if last_date == yesterday {
                // 昨天阅读过，连续天数+1
                tx.query_row(
                    "SELECT consecutive_reading_days FROM reading_stats WHERE id = 1",
                    [],
                    |row| row.get::<_, i32>(0),
                )
                .unwrap_or(0)
                    + 1
            } else {
                // 断掉了，重新开始
                1
            }
        } else {
            1
        };

        // 4. 更新累计统计数据
        tx.execute(
            "UPDATE reading_stats SET
             total_reading_time_seconds = total_reading_time_seconds + ?1,
             total_characters_read = total_characters_read + ?2,
             last_read_date = ?3,
             consecutive_reading_days = ?4
             WHERE id = 1",
            [
                &duration_seconds.to_string(),
                &characters_read.to_string(),
                &today,
                &consecutive_days.to_string(),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        tx.commit()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 获取阅读统计
    pub fn get_reading_stats(&self) -> StorageResult<crate::ffi::ReadingStats> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();

        // 获取累计统计
        let stats = conn
            .query_row(
                "SELECT total_reading_time_seconds, total_characters_read, 
                        books_read_count, books_completed_count, consecutive_reading_days
                 FROM reading_stats WHERE id = 1",
                [],
                |row| {
                    Ok(crate::ffi::ReadingStats {
                        total_reading_time_seconds: row.get(0)?,
                        total_characters_read: row.get(1)?,
                        books_read_count: row.get(2)?,
                        books_completed_count: row.get(3)?,
                        consecutive_reading_days: row.get(4)?,
                        today_reading_time_seconds: 0,
                        today_characters_read: 0,
                        average_reading_speed: 0.0,
                    })
                },
            )
            .optional()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .unwrap_or_default();

        // 获取今日数据
        let today_stats: Option<(i64, i64)> = conn
            .query_row(
                "SELECT reading_time_seconds, characters_read 
                 FROM daily_reading_records WHERE date = ?1",
                [&today],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let (today_time, today_chars) = today_stats.unwrap_or((0, 0));

        // 计算平均阅读速度（字/分钟）
        let avg_speed = if stats.total_reading_time_seconds > 0 {
            (stats.total_characters_read as f32 / stats.total_reading_time_seconds as f32) * 60.0
        } else {
            0.0
        };

        Ok(crate::ffi::ReadingStats {
            today_reading_time_seconds: today_time,
            today_characters_read: today_chars,
            average_reading_speed: avg_speed,
            ..stats
        })
    }

    /// 获取指定日期的阅读记录
    pub fn get_daily_record(
        &self,
        date: &str,
    ) -> StorageResult<Option<crate::ffi::DailyReadingRecord>> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let record = conn
            .query_row(
                "SELECT date, reading_time_seconds, characters_read, 
                        chapters_read, pages_read
                 FROM daily_reading_records WHERE date = ?1",
                [date],
                |row| {
                    Ok(crate::ffi::DailyReadingRecord {
                        date: row.get(0)?,
                        reading_time_seconds: row.get(1)?,
                        characters_read: row.get(2)?,
                        chapters_read: row.get(3)?,
                        pages_read: row.get(4)?,
                    })
                },
            )
            .optional()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(record)
    }

    /// 获取日期范围内的阅读记录
    pub fn get_daily_records_in_range(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> StorageResult<Vec<crate::ffi::DailyReadingRecord>> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let mut stmt = conn
            .prepare(
                "SELECT date, reading_time_seconds, characters_read, 
                        chapters_read, pages_read
                 FROM daily_reading_records
                 WHERE date >= ?1 AND date <= ?2
                 ORDER BY date ASC",
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let records = stmt
            .query_map([start_date, end_date], |row| {
                Ok(crate::ffi::DailyReadingRecord {
                    date: row.get(0)?,
                    reading_time_seconds: row.get(1)?,
                    characters_read: row.get(2)?,
                    chapters_read: row.get(3)?,
                    pages_read: row.get(4)?,
                })
            })
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(records)
    }

    /// 更新书籍阅读计数
    pub fn increment_books_read_count(&self) -> StorageResult<()> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        conn.execute(
            "UPDATE reading_stats SET books_read_count = books_read_count + 1 WHERE id = 1",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 更新完成阅读书籍计数
    pub fn increment_books_completed_count(&self) -> StorageResult<()> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        conn.execute(
            "UPDATE reading_stats SET books_completed_count = books_completed_count + 1 WHERE id = 1",
            [],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    // ==================== 排版缓存管理 ====================

    /// 保存排版缓存
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    /// * `chapter_id` - 章节 ID
    /// * `config_hash` - 排版配置的哈希值
    /// * `page_offsets` - 页面偏移量列表
    ///
    /// # 返回值
    ///
    /// 返回 `Ok(())` 如果保存成功
    pub fn save_layout_cache(
        &self,
        book_id: &str,
        chapter_id: i32,
        config_hash: &str,
        page_offsets: &[PageOffset],
    ) -> StorageResult<()> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;

        let page_offsets_json = serde_json::to_string(page_offsets)
            .map_err(|e| StorageError::SerializationError(e.to_string()))?;

        conn.execute(
            "INSERT INTO layout_cache
             (book_id, chapter_id, config_hash, page_offsets, total_pages, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(book_id, chapter_id, config_hash) DO UPDATE SET
             page_offsets = excluded.page_offsets,
             total_pages = excluded.total_pages,
             created_at = excluded.created_at",
            [
                book_id,
                &chapter_id.to_string(),
                config_hash,
                &page_offsets_json,
                &page_offsets.len().to_string(),
                &now.to_string(),
            ],
        )
        .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 获取排版缓存
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    /// * `chapter_id` - 章节 ID
    /// * `config_hash` - 排版配置的哈希值
    ///
    /// # 返回值
    ///
    /// 返回 `LayoutCacheResult`，包含是否命中缓存和缓存数据
    pub fn get_layout_cache(
        &self,
        book_id: &str,
        chapter_id: i32,
        config_hash: &str,
    ) -> StorageResult<LayoutCacheResult> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let result = conn
            .query_row(
                "SELECT id, book_id, chapter_id, config_hash, page_offsets,
                        total_pages, created_at
                 FROM layout_cache
                 WHERE book_id = ?1 AND chapter_id = ?2 AND config_hash = ?3",
                [book_id, &chapter_id.to_string(), config_hash],
                |row| {
                    let page_offsets_json: String = row.get(4).unwrap_or_default();
                    let page_offsets: Vec<PageOffset> =
                        serde_json::from_str(&page_offsets_json).unwrap_or_default();

                    Ok(CachedLayout {
                        chapter_id: row.get(2).unwrap_or(0),
                        config_hash: row.get(3).unwrap_or_default(),
                        page_offsets,
                        total_pages: row.get(5).unwrap_or(0),
                        created_at: row.get(6).unwrap_or(0),
                    })
                },
            )
            .optional();

        match result {
            Ok(Some(cached_layout)) => Ok(LayoutCacheResult {
                hit: true,
                cached_layout: Some(cached_layout),
            }),
            Ok(None) => Ok(LayoutCacheResult {
                hit: false,
                cached_layout: None,
            }),
            Err(e) => Err(StorageError::DatabaseError(e.to_string())),
        }
    }

    /// 清除书籍的所有排版缓存
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    ///
    /// # 返回值
    ///
    /// 返回删除的缓存数量
    pub fn clear_layout_cache(&self, book_id: &str) -> StorageResult<i32> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let affected = conn
            .execute("DELETE FROM layout_cache WHERE book_id = ?1", [book_id])
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(affected as i32)
    }

    /// 清除指定章节的排版缓存
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    /// * `chapter_id` - 章节 ID
    ///
    /// # 返回值
    ///
    /// 返回删除的缓存数量
    pub fn clear_chapter_layout_cache(&self, book_id: &str, chapter_id: i32) -> StorageResult<i32> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let affected = conn
            .execute(
                "DELETE FROM layout_cache WHERE book_id = ?1 AND chapter_id = ?2",
                [book_id, &chapter_id.to_string()],
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        Ok(affected as i32)
    }

    /// 获取书籍的所有排版缓存
    ///
    /// # 参数
    ///
    /// * `book_id` - 书籍 ID
    ///
    /// # 返回值
    ///
    /// 返回所有缓存的列表
    pub fn get_all_layout_cache(&self, book_id: &str) -> StorageResult<Vec<CachedLayout>> {
        let conn = self
            .conn
            .lock()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let mut stmt = conn
            .prepare(
                "SELECT chapter_id, config_hash, page_offsets, total_pages, created_at
                 FROM layout_cache
                 WHERE book_id = ?1
                 ORDER BY chapter_id ASC",
            )
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?;

        let caches = stmt
            .query_map([book_id], |row| {
                let page_offsets_json: String = row.get(2).unwrap_or_default();
                let page_offsets: Vec<PageOffset> =
                    serde_json::from_str(&page_offsets_json).unwrap_or_default();

                Ok(CachedLayout {
                    chapter_id: row.get(0).unwrap_or(0),
                    config_hash: row.get(1).unwrap_or_default(),
                    page_offsets,
                    total_pages: row.get(3).unwrap_or(0),
                    created_at: row.get(4).unwrap_or(0),
                })
            })
            .map_err(|e| StorageError::DatabaseError(e.to_string()))?
            .filter_map(|r| r.ok())
            .collect();

        Ok(caches)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::NamedTempFile;

    fn create_test_storage() -> SqliteStorage {
        let temp_file = NamedTempFile::new().unwrap();
        SqliteStorage::new(temp_file.path()).unwrap()
    }

    fn create_test_progress() -> ReadingProgress {
        ReadingProgress {
            chapter_id: 1,
            page_index: 10,
            total_pages: 100,
            progress: 0.1,
            reading_time_seconds: 3600,
            last_read_timestamp: 1234567890,
        }
    }

    fn create_test_bookmark(bookmark_id: &str) -> Bookmark {
        Bookmark {
            bookmark_id: bookmark_id.to_string(),
            book_id: "test_book".to_string(),
            chapter_id: 2,
            page_index: 5,
            title: "测试书签".to_string(),
            created_timestamp: 1234567890,
            note: Some("这是一个测试备注".to_string()),
        }
    }

    #[test]
    fn test_save_and_load_progress() {
        let storage = create_test_storage();
        let progress = create_test_progress();

        storage.save_progress("book1", &progress).unwrap();
        let loaded = storage.load_progress("book1").unwrap().unwrap();

        assert_eq!(loaded.chapter_id, progress.chapter_id);
        assert_eq!(loaded.page_index, progress.page_index);
        assert_eq!(loaded.total_pages, progress.total_pages);
        assert!((loaded.progress - progress.progress).abs() < f32::EPSILON);
    }

    #[test]
    fn test_update_progress() {
        let storage = create_test_storage();
        let mut progress = create_test_progress();

        storage.save_progress("book1", &progress).unwrap();

        progress.chapter_id = 5;
        progress.page_index = 50;
        storage.save_progress("book1", &progress).unwrap();

        let loaded = storage.load_progress("book1").unwrap().unwrap();
        assert_eq!(loaded.chapter_id, 5);
        assert_eq!(loaded.page_index, 50);
    }

    #[test]
    fn test_delete_progress() {
        let storage = create_test_storage();
        let progress = create_test_progress();

        storage.save_progress("book1", &progress).unwrap();
        storage.delete_progress("book1").unwrap();

        let loaded = storage.load_progress("book1").unwrap();
        assert!(loaded.is_none());
    }

    #[test]
    fn test_save_and_load_bookmarks() {
        let storage = create_test_storage();
        let bookmark1 = create_test_bookmark("bm1");
        let bookmark2 = create_test_bookmark("bm2");

        storage.save_bookmark("book1", &bookmark1).unwrap();
        storage.save_bookmark("book1", &bookmark2).unwrap();

        let bookmarks = storage.load_bookmarks("book1").unwrap();
        assert_eq!(bookmarks.len(), 2);
    }

    #[test]
    fn test_delete_bookmark() {
        let storage = create_test_storage();
        let bookmark = create_test_bookmark("bm1");

        storage.save_bookmark("book1", &bookmark).unwrap();
        let deleted = storage.delete_bookmark("book1", "bm1").unwrap();

        assert!(deleted);
        let bookmarks = storage.load_bookmarks("book1").unwrap();
        assert!(bookmarks.is_empty());
    }

    #[test]
    fn test_clear_bookmarks() {
        let storage = create_test_storage();
        let bookmark1 = create_test_bookmark("bm1");
        let bookmark2 = create_test_bookmark("bm2");

        storage.save_bookmark("book1", &bookmark1).unwrap();
        storage.save_bookmark("book1", &bookmark2).unwrap();

        let count = storage.clear_bookmarks("book1").unwrap();
        assert_eq!(count, 2);

        let bookmarks = storage.load_bookmarks("book1").unwrap();
        assert!(bookmarks.is_empty());
    }
}
