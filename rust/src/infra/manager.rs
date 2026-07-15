// ============================================================
// 文件作用：存储管理器 — SQLite + sled KV 统一管理
//
// 公有类型/函数：
//   - StorageManager — SQLite + sled 统一存储管理器
//   - new() — 初始化连接池并运行迁移
//   - pool() / kv() / data_dir() / close() — 生命周期管理
//   - export_db() / restore_from_backup() / hot_swap_db() — 备份/还原
//   - init_storage() — FFI 入口，创建 StorageManager 并注入全局单例
//   - storage() / ensure_storage() / storage_pool() — 全局单例访问
// ============================================================

//! 存储管理器 — SQLite 连接池 + 迁移 + 导出 + 全局单例

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::OnceLock;

use flutter_rust_bridge::frb;
use parking_lot::Mutex;
use sqlx::SqlitePool;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};

use crate::common::AppError;

use super::kv_store::KvStore;

// ==================== 全局单例 ====================

pub(crate) static STORAGE: OnceLock<StorageManager> = OnceLock::new();

/// 获取全局存储实例
pub fn storage() -> Option<&'static StorageManager> {
    STORAGE.get()
}

/// 确保存储已初始化
pub fn ensure_storage() -> Result<&'static StorageManager, AppError> {
    storage().ok_or(AppError::StorageNotInitialized)
}

/// 获取 storage pool 的简写，消除重复样板
pub fn storage_pool() -> Result<SqlitePool, AppError> {
    ensure_storage()?
        .pool()
        .map_err(|e| AppError::DatabaseError {
            reason: e.to_string(),
        })
}

/// 初始化全局存储实例
///
/// 创建 `StorageManager`（SQLite 连接池 + sled KV），注入全局单例 `STORAGE`。
/// 首次调用时创建数据目录并初始化存储；重复调用直接返回成功（幂等）。
///
/// # 参数
/// * `data_dir` - 数据存储目录路径
#[frb]
pub async fn init_storage(data_dir: String) -> Result<(), AppError> {
    let dir = Path::new(&data_dir).to_path_buf();

    if STORAGE.get().is_some() {
        tracing::warn!(
            "init_storage called repeatedly, ignored (data_dir={:?})",
            dir
        );
        return Ok(());
    }

    if !dir.exists() {
        tokio::fs::create_dir_all(&dir).await.map_err(|e| {
            AppError::FileWriteError { path: data_dir.into(), details: format!("Failed to create data directory: {}", e).into() }
        })?;
        tracing::info!("data_dir did not exist, created: {:?}", dir);
    } else {
        let db_path = dir.join("reader.db");
        if !db_path.exists() {
            tracing::warn!(
                "data_dir exists but reader.db not found, data may be lost: {:?}",
                dir
            );
        }
    }

    let manager = StorageManager::new(&dir).await?;
    STORAGE
        .set(manager)
        .map_err(|_| AppError::InternalError { reason: "Storage already initialized".into() })?;

    tracing::info!("init_storage complete: data_dir={:?}", dir);
    Ok(())
}

// ==================== StorageManager ====================

/// 存储管理器
/// 统一管理 SQLite (sqlx) 和 KV (sled) 存储
pub struct StorageManager {
    /// SQLx 连接池（Mutex 支持还原时热替换）
    pool: Mutex<Option<SqlitePool>>,
    /// KV 存储（用于排版缓存等）
    kv: Arc<KvStore>,
    /// 数据目录路径
    data_dir: PathBuf,
}

impl StorageManager {
    /// 创建新的存储管理器
    ///
    /// 初始化 SQLite 连接池并运行迁移，同时初始化 KV 存储（sled）。
    /// # 参数
    /// `data_dir` - 数据库文件和 KV 缓存的存放目录
    pub async fn new(data_dir: impl AsRef<Path>) -> Result<Self, AppError> {
        let data_dir = data_dir.as_ref().to_path_buf();
        std::fs::create_dir_all(&data_dir)
            .map_err(|e| AppError::FileReadError { path: data_dir.display().to_string(), details: format!("create dir: {e}") })?;

        let db_path = data_dir.join("reader.db");
        let pool = Self::create_pool(&db_path).await?;

        sqlx::migrate!("./migrations").run(&pool).await
            .map_err(|e| AppError::DatabaseError { reason: format!("DB migration failed: {e}") })?;

        let kv_path = data_dir.join("cache");
        let kv = KvStore::new(&kv_path)
            .map_err(|e| AppError::DatabaseError { reason: format!("KV init failed: {e}") })?;

        Ok(Self {
            pool: Mutex::new(Some(pool)),
            kv: Arc::new(kv),
            data_dir,
        })
    }

    pub(crate) async fn create_pool(db_path: &Path) -> Result<SqlitePool, AppError> {
        SqlitePoolOptions::new()
            // max_connections 提高至 8 以支持并行测试（WAL 模式支持并发读）。
            // 生产环境为单用户，无负面影响。
            .max_connections(8)
            .acquire_timeout(std::time::Duration::from_secs(15))
            .connect_with(
                SqliteConnectOptions::new()
                    .filename(db_path)
                    .create_if_missing(true)
                    .foreign_keys(true)
                    .journal_mode(sqlx::sqlite::SqliteJournalMode::Wal)
                    .synchronous(sqlx::sqlite::SqliteSynchronous::Normal)
                    .busy_timeout(std::time::Duration::from_secs(5))
                    .pragma("wal_autocheckpoint", "1000")
                    .pragma("temp_store", "MEMORY")
                    .pragma("cache_size", "-2000"),
            )
            .await
            .map_err(|e| AppError::DatabaseError { reason: format!("SQLite pool init failed: {e}") })
    }

    /// 获取 SQLite 连接池
    pub fn pool(&self) -> Result<SqlitePool, AppError> {
        self.pool
            .lock()
            .clone()
            .ok_or(AppError::StorageNotInitialized)
    }

    /// 获取 KV 存储引用
    pub fn kv(&self) -> Arc<KvStore> {
        Arc::clone(&self.kv)
    }

    /// 获取数据目录路径
    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    /// 关闭当前连接池
    pub async fn close(&self) -> Result<(), AppError> {
        self.kv.flush()?;
        let pool = self
            .pool
            .lock()
            .take();
        if let Some(pool) = pool {
            pool.close().await;
        }
        Ok(())
    }

    /// 从备份文件还原数据库并热替换连接池
    pub async fn restore_from_backup(&self, backup_path: impl AsRef<Path>) -> Result<(), AppError> {
        let backup_path = backup_path.as_ref();

        self.kv.flush()?;

        // 关闭旧连接池（先提取再 await，避免 MutexGuard 跨 await）
        let old_pool = self
            .pool
            .lock()
            .take();
        if let Some(old) = old_pool {
            old.close().await;
        }

        // WAL checkpoint 后复制备份文件
        let db_path = self.data_dir.join("reader.db");
        let temp_path = self.data_dir.join("reader_restore.db");
        std::fs::copy(backup_path, &temp_path)
            .map_err(|e| AppError::FileReadError { path: temp_path.display().to_string(), details: format!("copy backup: {e}") })?;

        // 在新文件上运行迁移以兼容旧备份
        let new_pool = Self::create_pool(&temp_path).await?;
        sqlx::migrate!("./migrations").run(&new_pool).await
            .map_err(|e| AppError::DatabaseError { reason: format!("restore migration failed: {e}") })?;
        new_pool.close().await;

        // 替换数据库文件
        std::fs::rename(&temp_path, &db_path)
            .map_err(|e| AppError::FileReadError { path: db_path.display().to_string(), details: format!("replace db: {e}") })?;

        // 打开新连接池
        let restored_pool = Self::create_pool(&db_path).await?;

        *self
            .pool
            .lock() = Some(restored_pool);

        tracing::info!("Database restored from {:?}", backup_path);
        Ok(())
    }

    /// 原子地热替换运行中的 db 连接池
    ///
    /// 调用者需自行保证 db_path 已被替换为目标文件（含 migration 跑过）。
    pub async fn hot_swap_db(&self) -> Result<(), AppError> {
        self.kv.flush()?;
        let old_pool = self
            .pool
            .lock()
            .take();
        if let Some(old) = old_pool {
            old.close().await;
        }
        let db_path = self.data_dir.join("reader.db");
        let new_pool = Self::create_pool(&db_path).await?;
        *self
            .pool
            .lock() = Some(new_pool);
        tracing::info!("Storage pool hot-swapped");
        Ok(())
    }

    /// 导出数据库文件
    ///
    /// 先刷 KV 缓存、执行 WAL checkpoint，再复制 db 文件到目标路径。
    pub async fn export_db(&self, dest_path: impl AsRef<Path>) -> Result<(), AppError> {
        let dest_path = dest_path.as_ref();

        self.kv.flush()?;

        let pool = self.pool()?;

        sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
            .execute(&pool)
            .await
            .map_err(|e| AppError::DatabaseError { reason: format!("WAL checkpoint failed: {e}") })?;

        let db_path = self.data_dir.join("reader.db");
        std::fs::copy(&db_path, dest_path)
            .map_err(|e| AppError::FileReadError { path: db_path.display().to_string(), details: format!("copy db: {e}") })?;

        tracing::info!("Database exported to {:?}", dest_path);
        Ok(())
    }
}
