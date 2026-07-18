//! 数据库备份与还原 API — 薄 FRB 封装层

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::domain::backup;

/// 获取当前数据库行数统计
#[frb]
pub async fn get_backup_stats() -> Result<backup::BackupStats, AppError> {
    backup::get_backup_stats().await
}

/// 导出数据库到指定路径
#[frb]
pub async fn export_database(dest_path: String) -> Result<backup::BackupManifest, AppError> {
    backup::export_database(dest_path).await
}

/// 只读读取备份 manifest
#[frb]
pub async fn inspect_backup(
    backup_path: String,
) -> Result<Option<backup::BackupManifest>, AppError> {
    backup::inspect_backup(backup_path).await
}

/// 从备份文件还原数据库
#[frb]
pub async fn restore_database(backup_path: String) -> Result<backup::BackupManifest, AppError> {
    backup::restore_database(backup_path).await
}

/// 清理指定时间戳之前的自动快照
#[frb]
pub async fn cleanup_auto_snapshots(older_than_unix: i64) -> Result<i64, AppError> {
    backup::cleanup_auto_snapshots(older_than_unix).await
}
