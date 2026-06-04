//! 数据库存储管理 — SQLite 连接池 + 迁移 + 导出

use std::path::{Path, PathBuf};
use std::sync::{Arc};
use parking_lot::Mutex;
use anyhow::{Context, Result};
use sqlx::SqlitePool;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};

use super::kv_store::KvStore;

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
    pub async fn new(data_dir: impl AsRef<Path>) -> Result<Self> {
        let data_dir = data_dir.as_ref().to_path_buf();
        std::fs::create_dir_all(&data_dir)?;

        let db_path = data_dir.join("reader.db");
        let pool = Self::create_pool(&db_path).await?;

        let migration_result = sqlx::migrate!("./migrations").run(&pool).await;
        migration_result.map_err(|e| {
            let details = format!("{e:#}");
            anyhow::anyhow!("Failed to run database migrations: {details}")
        })?;

        let kv_path = data_dir.join("cache");
        let kv = KvStore::new(&kv_path).context("Failed to initialize KV store")?;

        Ok(Self {
            pool: Mutex::new(Some(pool)),
            kv: Arc::new(kv),
            data_dir,
        })
    }

    pub(crate) async fn create_pool(db_path: &Path) -> Result<SqlitePool> {
        SqlitePoolOptions::new()
            .max_connections(1)
            .acquire_timeout(std::time::Duration::from_secs(5))
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
            .context("Failed to initialize SQLx pool")
    }

    pub fn pool(&self) -> Result<SqlitePool> {
        self.pool
            .lock()
            .clone()
            .ok_or_else(|| anyhow::anyhow!("Storage pool has been closed"))
    }

    pub fn kv(&self) -> Arc<KvStore> {
        Arc::clone(&self.kv)
    }

    pub fn data_dir(&self) -> &Path {
        &self.data_dir
    }

    /// 关闭当前连接池
    pub async fn close(&self) -> Result<()> {
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
    pub async fn restore_from_backup(&self, backup_path: impl AsRef<Path>) -> Result<()> {
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
            .with_context(|| format!("Failed to copy backup to {:?}", temp_path))?;

        // 在新文件上运行迁移以兼容旧备份
        let new_pool = Self::create_pool(&temp_path).await?;
        sqlx::migrate!("./migrations").run(&new_pool).await?;
        new_pool.close().await;

        // 替换数据库文件
        std::fs::rename(&temp_path, &db_path)
            .with_context(|| format!("Failed to replace database with {:?}", temp_path))?;

        // 打开新连接池
        let restored_pool = Self::create_pool(&db_path).await?;

        *self
            .pool
            .lock()=Some(restored_pool);

        tracing::info!("Database restored from {:?}", backup_path);
        Ok(())
    }

    /// 原子地热替换运行中的 db 连接池
    ///
    /// 调用者需自行保证 db_path 已被替换为目标文件（含 migration 跑过）。
    pub async fn hot_swap_db(&self) -> Result<()> {
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

    pub async fn export_db(&self, dest_path: impl AsRef<Path>) -> Result<()> {
        let dest_path = dest_path.as_ref();

        self.kv.flush()?;

        let pool = self.pool()?;

        sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
            .execute(&pool)
            .await
            .context("Failed to checkpoint WAL")?;

        let db_path = self.data_dir.join("reader.db");
        std::fs::copy(&db_path, dest_path).with_context(|| {
            format!(
                "Failed to copy database from {:?} to {:?}",
                db_path, dest_path
            )
        })?;

        tracing::info!("Database exported to {:?}", dest_path);
        Ok(())
    }
}
