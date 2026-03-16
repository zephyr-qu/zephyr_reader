//! 持久化存储模块
//!
//! 提供阅读进度和书签的持久化存储功能。
//! 支持多种存储后端：内存、JSON 文件、SQLite 数据库。
//! 包含 LRU 缓存用于高性能数据缓存。

use crate::ffi::{Bookmark, ReadingProgress};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};

pub mod lru_cache;
pub mod sqlite_storage;

pub use lru_cache::{CacheStats, ExpiringLruCache, LruCache};
pub use sqlite_storage::SqliteStorage;

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
}

/// 内存存储实现
///
/// 用于测试或临时存储，数据在应用重启后丢失
pub struct InMemoryStorage {
    progress: Arc<RwLock<HashMap<String, ReadingProgress>>>,
    bookmarks: Arc<RwLock<HashMap<String, Vec<Bookmark>>>>,
}

impl InMemoryStorage {
    /// 创建新的内存存储
    pub fn new() -> Self {
        Self {
            progress: Arc::new(RwLock::new(HashMap::new())),
            bookmarks: Arc::new(RwLock::new(HashMap::new())),
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
        let mut map = self
            .progress
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.insert(book_id.to_string(), progress.clone());
        Ok(())
    }

    fn load_progress(&self, book_id: &str) -> StorageResult<Option<ReadingProgress>> {
        let map = self
            .progress
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned())
    }

    fn delete_progress(&self, book_id: &str) -> StorageResult<()> {
        let mut map = self
            .progress
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.remove(book_id);
        Ok(())
    }

    fn save_bookmark(&self, book_id: &str, bookmark: &Bookmark) -> StorageResult<()> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.entry(book_id.to_string())
            .or_insert_with(Vec::new)
            .push(bookmark.clone());
        Ok(())
    }

    fn load_bookmarks(&self, book_id: &str) -> StorageResult<Vec<Bookmark>> {
        let map = self
            .bookmarks
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned().unwrap_or_default())
    }

    fn delete_bookmark(&self, book_id: &str, bookmark_id: &str) -> StorageResult<bool> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        if let Some(bookmarks) = map.get_mut(book_id) {
            let original_len = bookmarks.len();
            bookmarks.retain(|b| b.bookmark_id != bookmark_id);
            Ok(bookmarks.len() < original_len)
        } else {
            Ok(false)
        }
    }

    fn clear_bookmarks(&self, book_id: &str) -> StorageResult<usize> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        if let Some(bookmarks) = map.remove(book_id) {
            Ok(bookmarks.len())
        } else {
            Ok(0)
        }
    }

    fn get_all_progress(&self) -> StorageResult<Vec<(String, ReadingProgress)>> {
        let map = self
            .progress
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let result: Vec<(String, ReadingProgress)> =
            map.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        Ok(result)
    }

    fn get_all_bookmarks(&self) -> StorageResult<Vec<Bookmark>> {
        let map = self
            .bookmarks
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let result: Vec<Bookmark> = map.values().flat_map(|v| v.iter().cloned()).collect();
        Ok(result)
    }
}

/// JSON 文件存储实现
///
/// 将数据持久化到 JSON 文件，应用重启后数据保留
pub struct JsonFileStorage {
    storage_path: std::path::PathBuf,
    progress: Arc<RwLock<HashMap<String, ReadingProgress>>>,
    bookmarks: Arc<RwLock<HashMap<String, Vec<Bookmark>>>>,
}

impl JsonFileStorage {
    /// 创建新的 JSON 文件存储
    ///
    /// # 参数
    ///
    /// * `storage_path` - 存储文件路径
    pub fn new<P: AsRef<std::path::Path>>(storage_path: P) -> StorageResult<Self> {
        let storage = Self {
            storage_path: storage_path.as_ref().to_path_buf(),
            progress: Arc::new(RwLock::new(HashMap::new())),
            bookmarks: Arc::new(RwLock::new(HashMap::new())),
        };

        // 创建目录（如果不存在）
        if let Some(parent) = storage.storage_path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| StorageError::FileError(e.to_string()))?;
        }

        // 加载现有数据
        storage.load_from_file()?;

        Ok(storage)
    }

    /// 从文件加载数据
    fn load_from_file(&self) -> StorageResult<()> {
        if !self.storage_path.exists() {
            return Ok(());
        }

        let content = std::fs::read_to_string(&self.storage_path)
            .map_err(|e| StorageError::FileError(e.to_string()))?;

        let data: serde_json::Value = serde_json::from_str(&content)
            .map_err(|e| StorageError::SerializationError(e.to_string()))?;

        // 解析进度
        if let Some(progress_data) = data.get("progress") {
            let progress: HashMap<String, ReadingProgress> =
                serde_json::from_value(progress_data.clone())
                    .map_err(|e| StorageError::SerializationError(e.to_string()))?;
            let mut map = self
                .progress
                .write()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            *map = progress;
        }

        // 解析书签
        if let Some(bookmarks_data) = data.get("bookmarks") {
            let bookmarks: HashMap<String, Vec<Bookmark>> =
                serde_json::from_value(bookmarks_data.clone())
                    .map_err(|e| StorageError::SerializationError(e.to_string()))?;
            let mut map = self
                .bookmarks
                .write()
                .map_err(|e| StorageError::LockError(e.to_string()))?;
            *map = bookmarks;
        }

        Ok(())
    }

    /// 保存数据到文件
    fn save_to_file(&self) -> StorageResult<()> {
        let progress_map = self
            .progress
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let bookmarks_map = self
            .bookmarks
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;

        let data = serde_json::json!({
            "progress": *progress_map,
            "bookmarks": *bookmarks_map,
        });

        let content = serde_json::to_string_pretty(&data)
            .map_err(|e| StorageError::SerializationError(e.to_string()))?;

        std::fs::write(&self.storage_path, content)
            .map_err(|e| StorageError::FileError(e.to_string()))?;

        Ok(())
    }
}

impl ProgressStorage for JsonFileStorage {
    fn save_progress(&self, book_id: &str, progress: &ReadingProgress) -> StorageResult<()> {
        let mut map = self
            .progress
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.insert(book_id.to_string(), progress.clone());
        self.save_to_file()
    }

    fn load_progress(&self, book_id: &str) -> StorageResult<Option<ReadingProgress>> {
        let map = self
            .progress
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned())
    }

    fn delete_progress(&self, book_id: &str) -> StorageResult<()> {
        let mut map = self
            .progress
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.remove(book_id);
        self.save_to_file()
    }

    fn save_bookmark(&self, book_id: &str, bookmark: &Bookmark) -> StorageResult<()> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        map.entry(book_id.to_string())
            .or_insert_with(Vec::new)
            .push(bookmark.clone());
        self.save_to_file()
    }

    fn load_bookmarks(&self, book_id: &str) -> StorageResult<Vec<Bookmark>> {
        let map = self
            .bookmarks
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        Ok(map.get(book_id).cloned().unwrap_or_default())
    }

    fn delete_bookmark(&self, book_id: &str, bookmark_id: &str) -> StorageResult<bool> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        if let Some(bookmarks) = map.get_mut(book_id) {
            let original_len = bookmarks.len();
            bookmarks.retain(|b| b.bookmark_id != bookmark_id);
            let deleted = bookmarks.len() < original_len;
            if deleted {
                self.save_to_file()?;
            }
            Ok(deleted)
        } else {
            Ok(false)
        }
    }

    fn clear_bookmarks(&self, book_id: &str) -> StorageResult<usize> {
        let mut map = self
            .bookmarks
            .write()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let count = if let Some(bookmarks) = map.remove(book_id) {
            bookmarks.len()
        } else {
            0
        };
        self.save_to_file()?;
        Ok(count)
    }

    fn get_all_progress(&self) -> StorageResult<Vec<(String, ReadingProgress)>> {
        let map = self
            .progress
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let result: Vec<(String, ReadingProgress)> =
            map.iter().map(|(k, v)| (k.clone(), v.clone())).collect();
        Ok(result)
    }

    fn get_all_bookmarks(&self) -> StorageResult<Vec<Bookmark>> {
        let map = self
            .bookmarks
            .read()
            .map_err(|e| StorageError::LockError(e.to_string()))?;
        let result: Vec<Bookmark> = map.values().flat_map(|v| v.iter().cloned()).collect();
        Ok(result)
    }
}
