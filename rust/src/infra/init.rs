// ============================================================
// 文件作用：应用初始化入口函数 + 存储初始化 FFI
// ============================================================

use std::path::Path;

use flutter_rust_bridge::frb;

use crate::common::AppError;
use crate::infra::manager::StorageManager;

/// 应用初始化入口函数
#[frb(init)]
pub fn init_app() {
    use tracing_subscriber::EnvFilter;

    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(true)
        .try_init();

    flutter_rust_bridge::setup_default_user_utils();
    crate::parser::init_parser();

    tracing::info!("Rust reader engine initialized");
}

/// 初始化全局存储实例
///
/// 创建 StorageManager（SQLite 连接池 + redb KV），注入全局单例。
/// 首次调用创建数据目录并初始化；重复调用直接返回成功（幂等）。
#[frb]
pub async fn init_storage(data_dir: String) -> Result<(), AppError> {
    let dir = Path::new(&data_dir).to_path_buf();

    if crate::infra::manager::STORAGE.get().is_some() {
        tracing::warn!(
            "init_storage called repeatedly, ignored (data_dir={:?})",
            dir
        );
        return Ok(());
    }

    if !dir.exists() {
        tokio::fs::create_dir_all(&dir).await.map_err(|e| {
            AppError::FileWriteError {
                path: data_dir.into(),
                details: format!("Failed to create data directory: {}", e).into(),
            }
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
    crate::infra::manager::STORAGE
        .set(manager)
        .map_err(|_| AppError::InternalError {
            reason: "Storage already initialized".into(),
        })?;

    tracing::info!("init_storage complete: data_dir={:?}", dir);
    Ok(())
}

/// FRB 连接测试
#[frb]
pub fn test_connection() -> Result<String, AppError> {
    Ok("Rust reader engine connected successfully".to_string())
}
