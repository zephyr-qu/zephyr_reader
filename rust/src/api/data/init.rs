//! 存储初始化 API
//!
//! @dart_call - 被 Dart 侧数据服务初始化代码调用

use flutter_rust_bridge::frb;
use std::path::Path;

use crate::domain::AppError;
use crate::storage::STORAGE;
use crate::storage::StorageManager;

// ============================================================
// 文件作用：存储初始化 API — 初始化全局数据库存储实例。
//
// 公有函数：
//   - init_storage() — 初始化全局存储实例
// ============================================================

/// 初始化全局存储实例
///
/// # 参数
/// * `data_dir` - 数据存储目录路径
///
/// # 返回
/// 成功时返回 Ok(()), 失败时返回 AppError
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
