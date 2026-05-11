//! Rust 数据存储层
//!
//! 负责管理所有阅读相关数据的持久化：
//! - 阅读进度 (SQLite)
//! - 笔记/高亮 (SQLite)
//! - 书签 (SQLite)
//! - 全文索引 (SQLite)
//! - 排版缓存 (sled KV)
//! - 同步状态 (SQLite)

use std::path::Path;

use anyhow::{Context, Result};

pub mod db;
pub mod kv_store;
pub mod models;
pub mod repos;

pub use db::StorageManager;

// ==================== 全局存储实例 ====================

use once_cell::sync::OnceCell;

static STORAGE: OnceCell<StorageManager> = OnceCell::new();

/// 初始化全局存储
pub async fn init_storage(data_dir: impl AsRef<Path>) -> Result<()> {
    let manager = StorageManager::new(data_dir).await?;
    STORAGE
        .set(manager)
        .map_err(|_| anyhow::anyhow!("Storage already initialized"))?;
    Ok(())
}

/// 获取全局存储实例
pub fn storage() -> Option<&'static StorageManager> {
    STORAGE.get()
}

/// 确保存储已初始化
pub fn ensure_storage() -> Result<&'static StorageManager> {
    storage().context("Storage not initialized. Call init_storage() first.")
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[tokio::test]
    async fn test_storage_manager_init() {
        let temp_dir = TempDir::new().unwrap();
        let manager = StorageManager::new(temp_dir.path()).await.unwrap();
        assert!(manager.data_dir().exists());
    }
}
