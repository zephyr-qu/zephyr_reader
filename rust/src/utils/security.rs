//! 文件路径安全校验
//! 提供文件路径的规范化和安全性验证功能

use crate::domain::AppError;
use std::path::Path;

/// 验证文件路径（同步）
///
/// 检查路径是否存在且为文件，返回规范化后的绝对路径。
/// 用于防止路径遍历攻击和非法文件访问
pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::file_not_found(path_str));
    }
    if !path.is_file() {
        return Err(AppError::file_read_error(path_str, "path is not a file"));
    }
    let canonical = path
        .canonicalize()
        .map_err(|e| AppError::file_read_error(path_str, e.to_string()))?;
    Ok(canonical.to_string_lossy().to_string())
}

/// 验证文件路径（异步）
///
/// 通过 `spawn_blocking` 在阻塞线程池中执行同步校验，避免阻塞 async 运行时
pub async fn validate_file_path_async(path_str: &str) -> Result<String, AppError> {
    let path_str = path_str.to_string();
    tokio::task::spawn_blocking(move || validate_file_path(&path_str))
        .await
        .map_err(|e| AppError::task_panic("security sync", e.to_string()))?
}
