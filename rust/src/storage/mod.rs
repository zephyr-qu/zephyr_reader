//! Rust 数据存储层
//!
//! 负责管理所有阅读相关数据的持久化：
//! - 阅读进度 (SQLite)
//! - 笔记/高亮 (SQLite)
//! - 书签 (SQLite)
//! - 全文索引 (SQLite)
//! - 排版缓存 (sled KV)
//! - 同步状态 (SQLite)

use parking_lot::Mutex;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use anyhow::{Context, Result};

pub mod database;
pub mod kv_store;
pub mod models;
pub mod repositories;

use database::Database;
use kv_store::KvStore;

/// 存储管理器
///
/// 统一管理 SQLite 和 KV 存储，提供类型安全的 CRUD 接口
#[flutter_rust_bridge::frb(opaque)]
pub struct StorageManager {
    /// SQLite 数据库连接（使用 Mutex 保证线程安全）
    db: Arc<Mutex<Database>>,
    /// KV 存储（用于排版缓存等）
    kv: Arc<KvStore>,
    /// 数据目录路径
    data_dir: PathBuf,
}

impl StorageManager {
    /// 初始化存储系统
    ///
    /// # Arguments
    /// * `data_dir` - 数据存储目录（应用私有目录）
    pub fn new(data_dir: impl AsRef<Path>) -> Result<Self> {
        let data_dir = data_dir.as_ref().to_path_buf();
        std::fs::create_dir_all(&data_dir)?;

        // 初始化 SQLite
        let db_path = data_dir.join("reader.db");
        let db = Database::new(&db_path).context("Failed to initialize database")?;

        // 初始化 KV 存储
        let kv_path = data_dir.join("cache");
        let kv = KvStore::new(&kv_path).context("Failed to initialize KV store")?;

        Ok(Self {
            db: Arc::new(Mutex::new(db)),
            kv: Arc::new(kv),
            data_dir,
        })
    }

    /// 获取数据库访问
    pub fn db(&self) -> Arc<Mutex<Database>> {
        Arc::clone(&self.db)
    }

    /// 获取 KV 存储访问
    pub fn kv(&self) -> Arc<KvStore> {
        Arc::clone(&self.kv)
    }

    /// 获取数据目录路径
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    /// 关闭存储（刷盘）
    pub fn close(&self) -> Result<()> {
        self.kv.flush()?;
        Ok(())
    }
}

// ==================== 全局存储实例 ====================

use once_cell::sync::OnceCell;

static STORAGE: OnceCell<Arc<StorageManager>> = OnceCell::new();

/// 初始化全局存储
pub fn init_storage(data_dir: impl AsRef<Path>) -> Result<()> {
    let manager = StorageManager::new(data_dir)?;
    STORAGE
        .set(Arc::new(manager))
        .map_err(|_| anyhow::anyhow!("Storage already initialized"))?;
    Ok(())
}

/// 获取全局存储实例
pub fn storage() -> Option<Arc<StorageManager>> {
    STORAGE.get().cloned()
}

/// 确保存储已初始化
pub fn ensure_storage() -> Result<Arc<StorageManager>> {
    storage().context("Storage not initialized. Call init_storage() first.")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_storage_manager_init() {
        let temp_dir = TempDir::new().unwrap();
        let manager = StorageManager::new(temp_dir.path()).unwrap();
        assert!(manager.data_dir().exists());
    }
}
