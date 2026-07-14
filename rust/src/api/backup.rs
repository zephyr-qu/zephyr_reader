//! 数据库备份与还原 API
//!
//! 设计要点：
//! - 备份单元：单个 SQLite `.db` 文件，可被 SAF / WebDAV 任意传送
//! - manifest 嵌入 db 内部：使用 `_backup_meta` 单行表（导出时插入，导入时读取并删除）
//! - schema 兼容性：manifest 记录 `app_version` + `exported_at` + 行数统计；还原时按 app 版本策略拒绝
//! - 还原保护：先在 App 私有目录创建 `auto_snapshot_<ts>.db`，失败可回滚
//!
//! 公开 FFI 契约：
//! - `get_backup_stats() -> BackupStats`               当前数据库行数
//! - `export_database(dest_path) -> BackupManifest`    导出到路径，返回 manifest
//! - `inspect_backup(path) -> Option<BackupManifest>`  只读 manifest
//! - `restore_database(backup_path) -> BackupManifest` 还原 + 热替换连接池
//! - `cleanup_auto_snapshots(older_than_unix) -> i64` 清理旧快照

use std::fs::File;
use std::path::PathBuf;

use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

use crate::domain::AppError;
use crate::storage::ensure_storage;
use crate::domain::security::validate_file_path;

// ============================================================
// 文件作用：数据库备份与还原 API。
//
// 公有结构体：
//   - BackupManifest — 备份清单
//   - BackupStats — 数据库行数统计
//
// 公有函数：
//   - get_backup_stats() — 当前数据库行数
//   - export_database() — 导出数据库到路径
//   - inspect_backup() — 只读读取备份 manifest
//   - restore_database() — 从备份还原数据库
//   - cleanup_auto_snapshots() — 清理旧自动快照
//
// 私有函数：
//   - ensure_meta_table() — 创建临时元数据表
//   - read_manifest_from_pool() — 从连接池读取 manifest
//   - write_manifest_to_pool() — 写入 manifest
//   - drop_meta_table() — 删除元数据表
//   - count_stats() — 统计所有业务表行数
//   - semver_cmp() — 比较 semver 版本
//   - open_readonly_pool() — 创建只读连接池
// ============================================================

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
#[frb(non_opaque)]
pub struct BackupManifest {
    /// 当前应用版本（来自 Cargo.toml `version` 字段）
    pub app_version: String,
    /// 导出时间戳（Unix 秒）
    pub exported_at: i64,
    /// 数据库文件大小（字节）
    pub db_size: i64,
    /// 行数统计
    pub stats: BackupStats,
}

/// 当前数据库行数统计
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
#[frb(non_opaque)]
pub struct BackupStats {
    pub books: i64,
    pub chapters: i64,
    pub notes: i64,
    pub bookmarks: i64,
    pub reading_sessions: i64,
    pub reading_progress: i64,
    pub vocabulary_words: i64,
    pub categories: i64,
}

// ==================== 常量（sqlx 字面量，避 SqlSafeStr 错误） ====================

const CURRENT_APP_VERSION: &str = env!("CARGO_PKG_VERSION");

// 表名是编译期常量，sqlx 0.9 要求字面量。把所有 SQL 写成内联字面量。
// 约定：`_backup_meta` 表 schema 见下方注释。

// ==================== 内部辅助 ====================

/// 在 db 池中创建临时 `_backup_meta` 表。
async fn ensure_meta_table(pool: &sqlx::SqlitePool) -> Result<(), AppError> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS _backup_meta (
            id              INTEGER PRIMARY KEY CHECK (id = 1),
            app_version     TEXT    NOT NULL,
            exported_at     INTEGER NOT NULL,
            db_size         INTEGER NOT NULL,
            stats_json      TEXT    NOT NULL
        )",
    )
    .execute(pool)
    .await
    .map_err(|e| AppError::DatabaseError { reason: format!("ensure_meta_table: {e}") })?;
    Ok(())
}

/// 从 pool 中读取 BackupManifest
async fn read_manifest_from_pool(
    pool: &sqlx::SqlitePool,
) -> Result<Option<BackupManifest>, AppError> {
    let row: Option<(String, i64, i64, String)> = sqlx::query_as(
        "SELECT app_version, exported_at, db_size, stats_json FROM _backup_meta WHERE id = 1",
    )
    .fetch_optional(pool)
    .await
    .map_err(|e| AppError::DatabaseError { reason: format!("read_manifest: {e}") })?;

    let Some((app_version, exported_at, db_size, stats_json)) = row else {
        return Ok(None);
    };
    let stats: BackupStats = serde_json::from_str(&stats_json)
        .map_err(|e| AppError::DatabaseError { reason: format!("parse stats_json: {e}") })?;
    Ok(Some(BackupManifest {
        app_version,
        exported_at,
        db_size,
        stats,
    }))
}

/// 写 manifest 到 pool
async fn write_manifest_to_pool(
    pool: &sqlx::SqlitePool,
    manifest: &BackupManifest,
) -> Result<(), AppError> {
    let stats_json = serde_json::to_string(&manifest.stats)
        .map_err(|e| AppError::InternalError { reason: format!("serialize stats: {e}") })?;
    sqlx::query(
        "INSERT OR REPLACE INTO _backup_meta (id, app_version, exported_at, db_size, stats_json) VALUES (1, ?, ?, ?, ?)",
    )
    .bind(&manifest.app_version)
    .bind(manifest.exported_at)
    .bind(manifest.db_size)
    .bind(&stats_json)
    .execute(pool)
    .await
    .map_err(|e| AppError::DatabaseError { reason: format!("write_manifest: {e}") })?;
    Ok(())
}

/// 从 pool 中删除 _backup_meta 表（运行库不应长期保留）
async fn drop_meta_table(pool: &sqlx::SqlitePool) -> Result<(), AppError> {
    sqlx::query("DROP TABLE IF EXISTS _backup_meta")
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError { reason: format!("drop_meta_table: {e}") })?;
    Ok(())
}

/// 计算 pool 中各业务表的行数。表名是迁移文件字面量，无注入风险；
/// sqlx 0.9 要求字面量 SQL，此处用 `sqlx::query` + `fetch_one::<(i64,)>`。
async fn count_stats(pool: &sqlx::SqlitePool) -> Result<BackupStats, AppError> {
    async fn count(pool: &sqlx::SqlitePool, sql: &'static str) -> Result<i64, AppError> {
        let (n,): (i64,) = sqlx::query_as(sql)
            .fetch_one(pool)
            .await
            .map_err(|e| AppError::DatabaseError { reason: format!("count: {e}") })?;
        Ok(n)
    }
    Ok(BackupStats {
        books: count(pool, "SELECT COUNT(*) FROM books").await.unwrap_or(0),
        chapters: count(pool, "SELECT COUNT(*) FROM chapters").await.unwrap_or(0),
        notes: count(pool, "SELECT COUNT(*) FROM notes").await.unwrap_or(0),
        bookmarks: count(pool, "SELECT COUNT(*) FROM bookmarks").await.unwrap_or(0),
        reading_sessions: count(pool, "SELECT COUNT(*) FROM reading_sessions")
            .await
            .unwrap_or(0),
        reading_progress: count(pool, "SELECT COUNT(*) FROM reading_progress")
            .await
            .unwrap_or(0),
        vocabulary_words: count(pool, "SELECT COUNT(*) FROM vocabulary_words")
            .await
            .unwrap_or(0),
        categories: count(pool, "SELECT COUNT(*) FROM categories")
            .await
            .unwrap_or(0),
    })
}

/// 比较两个 semver 字符串（a > b 返回 1，a < b 返回 -1，equal 返回 0）
fn semver_cmp(a: &str, b: &str) -> i32 {
    let parse = |s: &str| -> Vec<u64> {
        s.split(|c: char| !c.is_ascii_digit())
            .filter_map(|p| p.parse::<u64>().ok())
            .collect()
    };
    let va = parse(a);
    let vb = parse(b);
    let n = va.len().max(vb.len());
    for i in 0..n {
        let x = *va.get(i).unwrap_or(&0);
        let y = *vb.get(i).unwrap_or(&0);
        if x > y {
            return 1;
        }
        if x < y {
            return -1;
        }
    }
    0
}

/// 创建只读连接池（用于 inspect_backup）
async fn open_readonly_pool(validated: &str) -> Result<sqlx::SqlitePool, AppError> {
    sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(1)
        .acquire_timeout(std::time::Duration::from_secs(5))
        .connect_with(
            sqlx::sqlite::SqliteConnectOptions::new()
                .filename(validated)
                .read_only(true)
                .create_if_missing(false),
        )
        .await
        .map_err(|e| AppError::DatabaseError { reason: format!("open readonly: {e}") })
}

// ==================== 公开 API ====================

/// 获取当前数据库行数统计
#[frb]
pub async fn get_backup_stats() -> Result<BackupStats, AppError> {
    let storage = ensure_storage()?;
    let pool = storage.pool()?;
    count_stats(&pool).await
}

/// 导出数据库到指定路径
///
/// 流程：写 `_backup_meta` 表 → WAL checkpoint → 复制 db → 重写 manifest 含 db_size → checkpoint → 删 meta。
#[frb]
pub async fn export_database(dest_path: String) -> Result<BackupManifest, AppError> {
    let validated = validate_file_path(&dest_path)?;
    let storage = ensure_storage()?;

    let pool = storage.pool()?;
    let stats = count_stats(&pool).await?;
    let mut manifest = BackupManifest {
        app_version: CURRENT_APP_VERSION.to_string(),
        exported_at: chrono::Utc::now().timestamp(),
        db_size: 0,
        stats,
    };
    ensure_meta_table(&pool).await?;
    write_manifest_to_pool(&pool, &manifest).await?;

    sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
        .execute(&pool)
        .await
        .map_err(|e| AppError::DatabaseError { reason: format!("wal_checkpoint: {e}").into() })?;

    let db_path = storage.data_dir().join("reader.db");
    let dest = PathBuf::from(&validated);
    std::fs::copy(&db_path, &dest)
        .map_err(|e| AppError::FileWriteError { path: validated.clone().into(), details: format!("copy db: {e}").into() })?;
    // 刷盘保证文件完整写入磁盘，防极端掉电损坏
    File::open(&dest)
        .and_then(|f| f.sync_all())
        .map_err(|e| AppError::FileWriteError { path: validated.clone().into(), details: format!("sync dest: {e}").into() })?;

    let db_size = std::fs::metadata(&dest)
        .map_err(|e| AppError::FileReadError { path: validated.clone().into(), details: format!("stat dest: {e}").into() })?
        .len() as i64;
    manifest.db_size = db_size;
    write_manifest_to_pool(&pool, &manifest).await?;
    sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
        .execute(&pool)
        .await
        .map_err(|e| AppError::DatabaseError { reason: format!("wal_checkpoint 2: {e}").into() })?;

    drop_meta_table(&pool).await?;

    tracing::info!("Database exported to {:?} ({} bytes)", dest, db_size);
    Ok(manifest)
}

/// 只读地读取备份文件的 manifest（不执行还原）
#[frb]
pub async fn inspect_backup(backup_path: String) -> Result<Option<BackupManifest>, AppError> {
    let validated = validate_file_path(&backup_path)?;
    let pool = open_readonly_pool(&validated).await?;
    let result = read_manifest_from_pool(&pool).await;
    pool.close().await;
    result
}

/// 从备份文件还原数据库
///
/// 流程：
/// 1. inspect 备份，读取 manifest；不存在则拒
/// 2. 校检 app_version：拒绝来自更新 app 的备份
/// 3. 快照当前 db 到 `<data_dir>/auto_snapshot_<ts>.db`（失败仅警告）
/// 4. 调用 `storage.restore_from_backup()`：关闭旧池→复制→迁移→热替换
#[frb]
pub async fn restore_database(backup_path: String) -> Result<BackupManifest, AppError> {
    let validated = validate_file_path(&backup_path)?;
    let storage = ensure_storage()?;

    let inspect_pool = open_readonly_pool(&validated).await?;
    let manifest = read_manifest_from_pool(&inspect_pool).await?;
    inspect_pool.close().await;
    let Some(manifest) = manifest else {
        return Err(AppError::InvalidInput { reason: "backup has no _backup_meta table (not produced by export_database or older version)".into() });
    };

    if semver_cmp(&manifest.app_version, CURRENT_APP_VERSION) > 0 {
        return Err(AppError::InvalidInput { reason: format!(
            "backup produced by newer app version {} (current {}), refusing to restore",
            manifest.app_version, CURRENT_APP_VERSION
        ).into() });
    }

    let db_path = storage.data_dir().join("reader.db");
    let snapshot_ts = chrono::Utc::now().timestamp();
    let snapshot_path = storage
        .data_dir()
        .join(format!("auto_snapshot_{snapshot_ts}.db"));
    if let Err(e) = std::fs::copy(&db_path, &snapshot_path) {
        tracing::warn!(
            "Failed to create pre-restore snapshot at {:?}: {}",
            snapshot_path,
            e
        );
    } else {
        tracing::info!("Pre-restore snapshot saved to {:?}", snapshot_path);
        // 刷盘保证快照完整，失败不阻塞还原
        if let Err(e) = File::open(&snapshot_path)
            .and_then(|f| f.sync_all())
        {
            tracing::warn!("Failed to sync snapshot file {:?}: {}", snapshot_path, e);
        }
    }

    storage
        .restore_from_backup(&validated)
        .await
        .map_err(|e| AppError::DatabaseError { reason: format!("restore_from_backup: {e}").into() })?;

    tracing::info!(
        "Database restored from {:?} (was {} bytes, app_version {})",
        validated,
        manifest.db_size,
        manifest.app_version
    );
    Ok(manifest)
}

/// 清理指定时间戳之前的自动快照
#[frb]
pub async fn cleanup_auto_snapshots(older_than_unix: i64) -> Result<i64, AppError> {
    let storage = ensure_storage()?;
    let mut count = 0i64;
    let entries = std::fs::read_dir(storage.data_dir()).map_err(|e| {
        AppError::FileReadError { path: storage.data_dir().to_string_lossy().as_ref().into(), details: e.to_string().into() }
    })?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name_str) = name.to_str() else { continue };
        if !name_str.starts_with("auto_snapshot_") || !name_str.ends_with(".db") {
            continue;
        }
        let ts_str = &name_str["auto_snapshot_".len()..name_str.len() - ".db".len()];
        if let Ok(ts) = ts_str.parse::<i64>() {
            if ts < older_than_unix {
                if std::fs::remove_file(entry.path()).is_ok() {
                    count += 1;
                }
            }
        }
    }
    Ok(count)
}

// ==================== 单元测试 ====================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn semver_cmp_basic() {
        assert_eq!(semver_cmp("1.0.0", "1.0.0"), 0);
        assert_eq!(semver_cmp("1.0.0", "0.9.9"), 1);
        assert_eq!(semver_cmp("0.9.9", "1.0.0"), -1);
        assert_eq!(semver_cmp("1.2.0", "1.2.1"), -1);
        assert_eq!(semver_cmp("1.10.0", "1.9.0"), 1);
        assert_eq!(semver_cmp("1.0", "1.0.0"), 0);
    }

    #[test]
    fn manifest_roundtrip_json() {
        let m = BackupManifest {
            app_version: "0.1.0".into(),
            exported_at: 1_717_000_000,
            db_size: 4096,
            stats: BackupStats {
                books: 10,
                chapters: 200,
                notes: 5,
                bookmarks: 3,
                reading_sessions: 20,
                reading_progress: 10,
                vocabulary_words: 50,
                categories: 3,
            },
        };
        let s = serde_json::to_string(&m).unwrap();
        let m2: BackupManifest = serde_json::from_str(&s).unwrap();
        assert_eq!(m2.app_version, m.app_version);
        assert_eq!(m2.stats.books, 10);
        assert_eq!(m2.stats.notes, 5);
    }
}
