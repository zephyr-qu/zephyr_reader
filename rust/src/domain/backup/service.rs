//! 数据库备份与还原业务逻辑

use std::fs::File;
use std::path::Path;
use std::path::PathBuf;

use crate::common::AppError;
use crate::common::security::validate_file_path;
use crate::domain::backup::{BackupManifest, BackupStats};
use crate::infra::ensure_storage;

const CURRENT_APP_VERSION: &str = env!("CARGO_PKG_VERSION");

// ==================== 内部辅助 ====================

/// 在 db 池中创建临时 `_backup_meta` 表
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
    .map_err(|e| AppError::DatabaseError {
        reason: format!("ensure_meta_table: {e}"),
    })?;
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
    .map_err(|e| AppError::DatabaseError {
        reason: format!("read_manifest: {e}"),
    })?;

    let Some((app_version, exported_at, db_size, stats_json)) = row else {
        return Ok(None);
    };
    let stats: BackupStats =
        serde_json::from_str(&stats_json).map_err(|e| AppError::DatabaseError {
            reason: format!("parse stats_json: {e}"),
        })?;
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
    let stats_json =
        serde_json::to_string(&manifest.stats).map_err(|e| AppError::InternalError {
            reason: format!("serialize stats: {e}"),
        })?;
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

/// 从 pool 中删除 _backup_meta 表
async fn drop_meta_table(pool: &sqlx::SqlitePool) -> Result<(), AppError> {
    sqlx::query("DROP TABLE IF EXISTS _backup_meta")
        .execute(pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("drop_meta_table: {e}"),
        })?;
    Ok(())
}

/// 计算 pool 中各业务表的行数
async fn count_stats(pool: &sqlx::SqlitePool) -> Result<BackupStats, AppError> {
    async fn count(pool: &sqlx::SqlitePool, sql: &'static str) -> Result<i64, AppError> {
        let (n,): (i64,) =
            sqlx::query_as(sql)
                .fetch_one(pool)
                .await
                .map_err(|e| AppError::DatabaseError {
                    reason: format!("count: {e}"),
                })?;
        Ok(n)
    }
    Ok(BackupStats {
        books: count(pool, "SELECT COUNT(*) FROM books").await.unwrap_or(0),
        chapters: count(pool, "SELECT COUNT(*) FROM chapters")
            .await
            .unwrap_or(0),
        notes: count(pool, "SELECT COUNT(*) FROM notes").await.unwrap_or(0),
        bookmarks: count(pool, "SELECT COUNT(*) FROM bookmarks")
            .await
            .unwrap_or(0),
        reading_sessions: count(pool, "SELECT COUNT(*) FROM reading_sessions")
            .await
            .unwrap_or(0),
        reading_progress: count(pool, "SELECT COUNT(*) FROM reading_progress")
            .await
            .unwrap_or(0),
        categories: count(pool, "SELECT COUNT(*) FROM categories")
            .await
            .unwrap_or(0),
    })
}

/// 比较两个 semver 字符串
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

/// 创建只读连接池
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
        .map_err(|e| AppError::DatabaseError {
            reason: format!("open readonly: {e}"),
        })
}

// ==================== 公开 API ====================

/// 获取当前数据库行数统计
pub async fn get_backup_stats() -> Result<BackupStats, AppError> {
    let storage = ensure_storage()?;
    let pool = storage.pool()?;
    count_stats(&pool).await
}

/// 导出数据库到指定路径
pub async fn export_database(dest_path: String) -> Result<BackupManifest, AppError> {
    let dest = Path::new(&dest_path);
    let parent = dest.parent().ok_or_else(|| AppError::InvalidInput {
        reason: "export path has no parent directory".into(),
    })?;
    if !parent.exists() {
        return Err(AppError::FileNotFound {
            path: dest_path.clone(),
        });
    }
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
        .map_err(|e| AppError::DatabaseError {
            reason: format!("wal_checkpoint: {e}"),
        })?;

    let db_path = storage.data_dir().join("reader.db");
    let dest = PathBuf::from(&dest_path);
    std::fs::copy(&db_path, &dest).map_err(|e| AppError::FileWriteError {
        path: dest_path.clone(),
        details: format!("copy db: {e}"),
    })?;
    File::open(&dest)
        .and_then(|f| f.sync_all())
        .map_err(|e| AppError::FileWriteError {
            path: dest_path.clone(),
            details: format!("sync dest: {e}"),
        })?;

    let db_size = std::fs::metadata(&dest)
        .map_err(|e| AppError::FileReadError {
            path: dest_path.clone(),
            details: format!("stat dest: {e}"),
        })?
        .len() as i64;
    manifest.db_size = db_size;
    write_manifest_to_pool(&pool, &manifest).await?;
    sqlx::query("PRAGMA wal_checkpoint(TRUNCATE)")
        .execute(&pool)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("wal_checkpoint 2: {e}"),
        })?;

    drop_meta_table(&pool).await?;
    tracing::info!("Database exported to {:?} ({} bytes)", dest, db_size);
    Ok(manifest)
}

/// 只读读取备份 manifest
pub async fn inspect_backup(backup_path: String) -> Result<Option<BackupManifest>, AppError> {
    let validated = validate_file_path(&backup_path)?;
    let pool = open_readonly_pool(&validated).await?;
    let result = read_manifest_from_pool(&pool).await;
    pool.close().await;
    result
}

/// 从备份文件还原数据库
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
        return Err(AppError::InvalidInput {
            reason: format!(
                "backup produced by newer app version {} (current {}), refusing to restore",
                manifest.app_version, CURRENT_APP_VERSION
            ),
        });
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
        if let Err(e) = File::open(&snapshot_path).and_then(|f| f.sync_all()) {
            tracing::warn!("Failed to sync snapshot file {:?}: {}", snapshot_path, e);
        }
    }

    storage
        .restore_from_backup(&validated)
        .await
        .map_err(|e| AppError::DatabaseError {
            reason: format!("restore_from_backup: {e}"),
        })?;

    tracing::info!(
        "Database restored from {:?} (was {} bytes, app_version {})",
        validated,
        manifest.db_size,
        manifest.app_version
    );
    Ok(manifest)
}

/// 清理指定时间戳之前的自动快照
pub async fn cleanup_auto_snapshots(older_than_unix: i64) -> Result<i64, AppError> {
    let storage = ensure_storage()?;
    let mut count = 0i64;
    let entries = std::fs::read_dir(storage.data_dir()).map_err(|e| AppError::FileReadError {
        path: storage.data_dir().to_string_lossy().as_ref().into(),
        details: e.to_string(),
    })?;
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name_str) = name.to_str() else {
            continue;
        };
        if !name_str.starts_with("auto_snapshot_") || !name_str.ends_with(".db") {
            continue;
        }
        let ts_str = &name_str["auto_snapshot_".len()..name_str.len() - ".db".len()];
        if let Ok(ts) = ts_str.parse::<i64>()
            && ts < older_than_unix
            && std::fs::remove_file(entry.path()).is_ok()
        {
            count += 1;
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
                categories: 3,
            },
        };
        let s = serde_json::to_string(&m).expect("serialize BackupManifest");
        let m2: BackupManifest = serde_json::from_str(&s).expect("deserialize BackupManifest");
        assert_eq!(m2.app_version, m.app_version);
        assert_eq!(m2.stats.books, 10);
    }
}
