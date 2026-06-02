//! 数据库备份与还原 API
//!
//! 提供数据库的导出和导入功能。

use flutter_rust_bridge::frb;

use crate::domain::AppError;
use crate::storage::ensure_storage;
use crate::utils::security::validate_file_path_async;

/// 导出数据库到指定路径
#[frb]
pub async fn export_database(dest_path: String) -> Result<(), AppError> {
    let validated = validate_file_path_async(&dest_path).await?;
    let storage = ensure_storage().map_err(|_| AppError::storage_not_initialized())?;
    storage
        .export_db(&validated)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    Ok(())
}

/// 从备份文件还原数据库
#[frb]
pub async fn restore_database(backup_path: String) -> Result<(), AppError> {
    let validated = validate_file_path_async(&backup_path).await?;
    let storage = ensure_storage().map_err(|_| AppError::storage_not_initialized())?;
    storage
        .restore_from_backup(&validated)
        .await
        .map_err(|e| AppError::database_error(e.to_string()))?;
    Ok(())
}
