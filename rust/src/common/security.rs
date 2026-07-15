// ============================================================
// 文件作用：文件路径安全校验，提供路径规范化和安全性验证
//
// 公有函数：
//   - validate_file_path() — 验证文件路径存在性并返回规范路径
// ============================================================

//! 文件路径安全校验
//! 提供文件路径的规范化和安全性验证功能

use crate::common::AppError;
use std::path::Path;

/// 验证文件路径（同步）
///
/// 检查路径是否存在且为文件，返回规范化后的绝对路径。
/// 用于防止路径遍历攻击和非法文件访问
pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() {
        return Err(AppError::FileNotFound {
            path: path_str.into(),
        });
    }
    if !path.is_file() {
        return Err(AppError::FileReadError {
            path: path_str.into(),
            details: "path is not a file".into(),
        });
    }
    let canonical = path.canonicalize().map_err(|e| AppError::FileReadError {
        path: path_str.into(),
        details: e.to_string(),
    })?;
    Ok(canonical.to_string_lossy().to_string())
}
