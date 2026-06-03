//! Rust 数据存储层
//!
//! 负责管理所有阅读相关数据的持久化：
//! - 阅读进度 (SQLite)
//! - 笔记/高亮 (SQLite)
//! - 书签 (SQLite)
//! - 全文索引 (SQLite)
//! - 排版缓存 (sled KV)
//! - 同步状态 (SQLite)

pub mod db;
pub mod kv_store;
pub mod models;
pub mod repos;

use std::sync::OnceLock;

pub use db::StorageManager;

use anyhow::{Context, Result};

use crate::domain::AppError;

// ==================== 全局存储实例 ====================

pub(crate) static STORAGE: OnceLock<StorageManager> = OnceLock::new();

/// 获取全局存储实例
pub fn storage() -> Option<&'static StorageManager> {
    STORAGE.get()
}

/// 确保存储已初始化
pub fn ensure_storage() -> Result<&'static StorageManager> {
    storage().context("Storage not initialized. Call init_storage() first.")
}

/// 获取 storage pool 的简写，消除重复样板
pub fn storage_pool() -> Result<sqlx::SqlitePool, AppError> {
    ensure_storage()
        .map_err(|_| AppError::storage_not_initialized())?
        .pool()
        .map_err(|e| AppError::database_error(e.to_string()))
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
