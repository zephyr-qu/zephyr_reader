//! 持久化存储模块（已弃用 - 仅用于向后兼容）
//!
//! **注意：此模块已弃用。所有持久化存储操作已迁移到 Flutter 侧（使用 Drift）。**
//!
//! 此模块现在仅提供内存存储实现，用于临时存储和向后兼容。
//! 应用重启后数据不会保留。
//!
//! # 迁移指南
//!
//! 所有存储操作现在应通过 Flutter 侧的 Drift 数据库进行：
//! - 阅读进度：`ReadingProgressService` (Flutter)
//! - 书签：`BookmarkService` (Flutter)
//! - 排版缓存：`LayoutCacheService` (Flutter)
//! - 阅读统计：`ReadingStatsService` (Flutter)

use crate::ffi::{Bookmark, CachedLayout, DailyReadingRecord, LayoutCacheResult, PageOffset, ReadingProgress, ReadingStats};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

pub mod lru_cache;

pub use lru_cache::{CacheStats, LruCache};

/// 排版缓存结构
#[derive(Debug, Clone)]
pub struct LayoutCacheEntry {
    pub page_offsets: Vec<PageOffset>,
}

/// 存储结果类型
pub type StorageResult<T> = Result<T, StorageError>;

/// 存储错误类型
#[derive(Debug, Clone)]
pub enum StorageError {
    /// 文件操作失败
    FileError(String),
    /// 数据库操作失败
    DatabaseError(String),
    /// 序列化/反序列化失败
    SerializationError(String),
    /// 数据未找到
    NotFound(String),
    /// 锁获取失败（多线程同步错误）
    LockError(String),
    /// 其他错误
    Other(String),
}

impl std::fmt::Display for StorageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::FileError(msg) => write!(f, "文件操作失败：{}", msg),
            Self::DatabaseError(msg) => write!(f, "数据库操作失败：{}", msg),
            Self::SerializationError(msg) => write!(f, "序列化失败：{}", msg),
            Self::NotFound(msg) => write!(f, "数据未找到：{}", msg),
            Self::LockError(msg) => write!(f, "锁获取失败：{}", msg),
            Self::Other(msg) => write!(f, "错误：{}", msg),
        }
    }
}

impl std::error::Error for StorageError {}

/// 存储后端 trait
///
/// 定义存储进度和书签的接口
/// 
/// **注意**: 所有持久化操作已迁移到 Flutter 侧。
/// 此 trait 的方法现在仅用于临时内存存储，数据不会持久化。
pub trait ProgressStorage: Send + Sync {
    /// 保存阅读进度
    fn save_progress(&self, book_id: &str, progress: &ReadingProgress) -> StorageResult<()>;

    /// 加载阅读进度
    fn load_progress(&self, book_id: &str) -> StorageResult<Option<ReadingProgress>>;

    /// 删除阅读进度
    fn delete_progress(&self, book_id: &str) -> StorageResult<()>;

    /// 获取所有阅读进度
    fn get_all_progress(&self) -> StorageResult<Vec<(String, ReadingProgress)>>;

    /// 保存书签
    fn save_bookmark(&self, book_id: &str, bookmark: &Bookmark) -> StorageResult<()>;

    /// 加载书籍的所有书签
    fn load_bookmarks(&self, book_id: &str) -> StorageResult<Vec<Bookmark>>;

    /// 删除书签
    fn delete_bookmark(&self, book_id: &str, bookmark_id: &str) -> StorageResult<bool>;

    /// 清除书籍的所有书签
    fn clear_bookmarks(&self, book_id: &str) -> StorageResult<usize>;

    /// 获取所有书签
    fn get_all_bookmarks(&self) -> StorageResult<Vec<Bookmark>>;

    // ==================== 阅读统计（内存实现，不持久化）====================

    /// 记录阅读会话
    fn record_reading_session(
        &self,
        book_id: &str,
        chapter_id: i32,
        duration_seconds: i64,
        characters_read: i64,
    ) -> StorageResult<()>;

    /// 获取阅读统计
    fn get_reading_stats(&self) -> StorageResult<ReadingStats>;

    /// 获取指定日期的阅读记录
    fn get_daily_record(&self, date: &str) -> StorageResult<Option<DailyReadingRecord>>;

    /// 获取日期范围内的阅读记录
    fn get_daily_records_in_range(
        &self,
        start_date: &str,
        end_date: &str,
    ) -> StorageResult<Vec<DailyReadingRecord>>;

    /// 增加已读书籍计数
    fn increment_books_read_count(&self) -> StorageResult<()>;

    /// 增加已完成书籍计数
    fn increment_books_completed_count(&self) -> StorageResult<()>;

    // ==================== 排版缓存（内存实现，不持久化）====================

    /// 保存排版缓存
    fn save_layout_cache(
        &self,
        book_id: &str,
        chapter_id: i32,
        config_hash: &str,
        page_offsets: &[PageOffset],
    ) -> StorageResult<()>;

    /// 获取排版缓存
    fn get_layout_cache(
        &self,
        book_id: &str,
        chapter_id: i32,
        config_hash: &str,
    ) -> StorageResult<LayoutCacheResult>;

    /// 清除书籍的所有排版缓存
    fn clear_layout_cache(&self, book_id: &str) -> StorageResult<usize>;

    /// 清除指定章节的排版缓存
    fn clear_chapter_layout_cache(&self, book_id: &str, chapter_id: i32) -> StorageResult<usize>;

    /// 获取书籍的所有排版缓存
    fn get_all_layout_cache(&self, book_id: &str) -> StorageResult<Vec<CachedLayout>>;
}

/// 内存存储实现（默认）
///
/// 用于临时存储，数据在应用重启后丢失
/// 所有持久化操作应使用 Flutter 侧的 Drift 数据库
pub struct InMemoryStorage {
    progress: Arc<RwLock<HashMap<String, ReadingProgress>>>,
    bookmarks: Arc<RwLock<HashMap<String, Vec<Bookmark>>>>,
    // 阅读统计（内存实现）
    reading_stats: Arc<RwLock<ReadingStats>>,
    daily_records: Arc<RwLock<HashMap<String, DailyReadingRecord>>>,
    // 排版缓存（内存实现）
    layout_cache: Arc<RwLock<HashMap<String, HashMap<i32, LayoutCacheEntry>>>>,
}

impl InMemoryStorage {
    /// 创建新的内存存储
    pub fn new() -> Self {
        Self {
            progress: Arc::new(RwLock::new(HashMap::new())),
            bookmarks: Arc::new(RwLock::new(HashMap::new())),
            reading_stats: Arc::new(RwLock::new(ReadingStats::default())),
            daily_records: Arc::new(RwLock::new(HashMap::new())),
            layout_cache: Arc::new(RwLock::new(HashMap::new())),
        }
    }
}

impl Default for InMemoryStorage {
    fn default() -> Self {
        Self::new()
    }
}

impl ProgressStorage for InMemoryStorage {
    fn save_progress(&self, book_id: &str, progress: &ReadingProgress) -> StorageResult<()> {
        let mut map = self.progress.write().map_err(|e| StorageError::LockError(e.to_string()))?;
        map.insert(book_id.to_string(), progress.clone());
        Ok(())
    }

    fn load_progress(&self, book_id: &str) -> StorageResult<Option<ReadingProgress>> {
        let map = self.progress.read().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned())
    }

    fn delete_progress(&self, book_id: &str) -> StorageResult<()> {
        let mut map = self.progress.write().map_err(|e| StorageError::LockError(e.to_string()))?;
        map.remove(book_id);
        Ok(())
    }

    fn get_all_progress(&self) -> StorageResult<Vec<(String, ReadingProgress)>> {
        let map = self.progress.read().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.iter().map(|(k, v)| (k.clone(), v.clone())).collect())
    }

    fn save_bookmark(&self, book_id: &str, bookmark: &Bookmark) -> StorageResult<()> {
        let mut map = self.bookmarks.write().map_err(|e| StorageError::LockError(e.to_string()))?;
        let bookmarks = map.entry(book_id.to_string()).or_insert_with(Vec::new);
        bookmarks.push(bookmark.clone());
        Ok(())
    }

    fn load_bookmarks(&self, book_id: &str) -> StorageResult<Vec<Bookmark>> {
        let map = self.bookmarks.read().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned().unwrap_or_default())
    }

    fn delete_bookmark(&self, book_id: &str, bookmark_id: &str) -> StorageResult<bool> {
        let mut map = self.bookmarks.write().map_err(|e| StorageError::LockError(e.to_string()))?;
        if let Some(bookmarks) = map.get_mut(book_id) {
            let len = bookmarks.len();
            bookmarks.retain(|b| b.bookmark_id != bookmark_id);
            Ok(bookmarks.len() != len)
        } else {
            Ok(false)
        }
    }

    fn clear_bookmarks(&self, book_id: &str) -> StorageResult<usize> {
        let mut map = self.bookmarks.write().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.remove(book_id).map(|v| v.len()).unwrap_or(0))
    }

    fn get_all_bookmarks(&self) -> StorageResult<Vec<Bookmark>> {
        let map = self.bookmarks.read().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.values().flatten().cloned().collect())
    }

    // ==================== 阅读统计（内存实现，不持久化）====================

    fn record_reading_session(
        &self,
        _book_id: &str,
        _chapter_id: i32,
        _duration_seconds: i64,
        _characters_read: i64,
    ) -> StorageResult<()> {
        // 内存实现：不执行任何操作，仅记录日志
        tracing::debug!("记录阅读会话（内存存储，不持久化）");
        Ok(())
    }

    fn get_reading_stats(&self) -> StorageResult<ReadingStats> {
        // 内存实现：返回默认统计
        let stats = self.reading_stats.read().map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(stats.clone())
    }

    fn get_daily_record(&self, _date: &str) -> StorageResult<Option<DailyReadingRecord>> {
        // 内存实现：返回 None
        Ok(None)
    }

    fn get_daily_records_in_range(
        &self,
        _start_date: &str,
        _end_date: &str,
    ) -> StorageResult<Vec<DailyReadingRecord>> {
        // 内存实现：返回空列表
        Ok(vec![])
    }

    fn increment_books_read_count(&self) -> StorageResult<()> {
        // 内存实现：不执行任何操作
        tracing::debug!("增加已读书籍计数（内存存储，不持久化）");
        Ok(())
    }

    fn increment_books_completed_count(&self) -> StorageResult<()> {
        // 内存实现：不执行任何操作
        tracing::debug!("增加已完成书籍计数（内存存储，不持久化）");
        Ok(())
    }

    // ==================== 排版缓存（内存实现，不持久化）====================

    fn save_layout_cache(
        &self,
        book_id: &str,
        chapter_id: i32,
        config_hash: &str,
        page_offsets: &[PageOffset],
    ) -> StorageResult<()> {
        // 内存实现：仅记录日志，不实际存储
        tracing::debug!(
            "保存排版缓存（内存存储，不持久化）：book={}, chapter={}, hash={}",
            book_id,
            chapter_id,
            config_hash
        );
        Ok(())
    }

    fn get_layout_cache(
        &self,
        _book_id: &str,
        _chapter_id: i32,
        _config_hash: &str,
    ) -> StorageResult<LayoutCacheResult> {
        // 内存实现：返回未命中
        Ok(LayoutCacheResult {
            hit: false,
            cached_layout: None,
        })
    }

    fn clear_layout_cache(&self, _book_id: &str) -> StorageResult<usize> {
        // 内存实现：返回 0
        Ok(0)
    }

    fn clear_chapter_layout_cache(&self, _book_id: &str, _chapter_id: i32) -> StorageResult<usize> {
        // 内存实现：返回 0
        Ok(0)
    }

    fn get_all_layout_cache(&self, _book_id: &str) -> StorageResult<Vec<CachedLayout>> {
        // 内存实现：返回空列表
        Ok(vec![])
    }
}

/// 获取全局存储实例（内存实现）
///
/// **注意：此函数返回的是内存存储，数据不会持久化。**
/// 所有持久化操作应使用 Flutter 侧的 Drift 数据库。
pub fn get_storage_instance() -> Result<Arc<dyn ProgressStorage>, StorageError> {
    lazy_static::lazy_static! {
        static ref STORAGE: Arc<dyn ProgressStorage> = Arc::new(InMemoryStorage::new());
    }
    Ok(STORAGE.clone())
}

// 所有 SQLite 操作已迁移到 Flutter 侧
// 此模块仅提供内存存储实现用于临时存储和向后兼容
