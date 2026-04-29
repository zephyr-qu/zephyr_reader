//! 安全路径验证模块
//!
//! 提供严格的路径验证逻辑，防止路径遍历攻击、符号链接攻击等安全漏洞。

use crate::api::core::ALLOWED_BASE_DIR;
use crate::ffi::ParserError;
use std::path::{Path, PathBuf};

/// 最大允许文件大小（500MB）
/// 防止超大文件导致内存耗尽，同时支持大型扫描版 PDF 和 EPUB 合集
const MAX_FILE_SIZE: u64 = 500 * 1024 * 1024;

/// 验证文件路径是否安全
///
/// 确保文件路径在允许的基目录内，防止路径遍历攻击。
///
/// # 参数
///
/// * `file_path` - 待验证的文件路径
/// * `allowed_base` - 允许的基目录路径（字符串）
///
/// # 返回值
///
/// * `Ok(String)` - 验证通过的规范化路径
/// * `Err(ParserError)` - 路径不安全或无效
#[allow(dead_code)]
pub(crate) fn validate_path_securely(file_path: &str, allowed_base: &str) -> Result<String, ParserError> {
    let allowed_base_path = Path::new(allowed_base);

    // 1. 检查空字节（路径截断攻击）
    if file_path.contains('\0') {
        return Err(ParserError::SecurityError(
            "路径包含空字节，可能存在路径截断攻击".to_string(),
        ));
    }

    // 2. 规范化并解析路径
    let mut path_buf = PathBuf::from(file_path);

    // 处理相对路径
    if path_buf.is_relative() {
        path_buf = allowed_base_path.join(path_buf);
    }

    // 3. 获取规范路径（解析符号链接）
    let canonical_path = path_buf
        .canonicalize()
        .map_err(|_| ParserError::FileNotFound {
            path: file_path.to_string(),
            reason: "文件不存在或无法访问".to_string(),
        })?;

    // 4. 获取规范的基目录
    let canonical_base = allowed_base_path
        .canonicalize()
        .map_err(|_| ParserError::ConfigError("基础目录无效".to_string()))?;

    // 5. 验证路径是否在允许的目录内
    if !canonical_path.starts_with(&canonical_base) {
        return Err(ParserError::SecurityError(format!(
            "路径遍历攻击检测：文件路径必须在 {} 目录内",
            canonical_base.display(),
        )));
    }
    Ok(canonical_path.to_string_lossy().to_string())
}

/// 验证文件路径并返回规范化的路径
///
/// # 安全性
///
/// 此函数直接调用 `canonicalize()` 避免 TOCTOU 竞态条件，
/// 不分离 `exists()` 检查，确保路径验证的原子性。
///
/// # 注意
///
/// 此函数使用严格的路径规范化，确保路径安全性。
pub(crate) fn validate_file_path(file_path: &str) -> Result<String, ParserError> {
    // 1. 检查空字节（路径截断攻击）
    if file_path.contains('\0') {
        return Err(ParserError::SecurityError(
            "路径包含空字节，可能存在路径截断攻击".to_string(),
        ));
    }

    let path = std::path::Path::new(file_path);

    // 2. 直接规范化路径（避免 TOCTOU 竞态条件）
    // 不分离 exists() 检查，通过 canonicalize() 的结果判断文件是否存在
    let canonical_path = path.canonicalize().map_err(|e| {
        if e.kind() == std::io::ErrorKind::NotFound {
            ParserError::file_not_found(file_path)
        } else {
            ParserError::FileReadError {
                path: file_path.to_string(),
                message: format!("无法规范化路径: {}", e),
            }
        }
    })?;

    // 3. 检查允许的基础目录（使用 RwLock 替代 OnceCell）
    // 如果未设置基目录，默认拒绝所有文件访问（fail closed），
    // 调用者必须先调用 set_allowed_base_dir() 明确授权可访问的目录范围
    {
        let guard = ALLOWED_BASE_DIR.read();
        let base_dir = guard.as_ref().ok_or_else(|| {
            ParserError::SecurityError(
                "未设置允许的基目录，文件访问被拒绝。请先调用 set_allowed_base_dir() 设置允许的基目录。".to_string(),
            )
        })?;

        if !canonical_path.starts_with(base_dir.as_path()) {
            return Err(ParserError::SecurityError(format!(
                "文件必须在 {} 目录内",
                base_dir.display()
            )));
        }
    }

    // 4. 检查文件大小（防止超大文件耗尽内存）
    let metadata = std::fs::metadata(&canonical_path).map_err(|e| ParserError::FileReadError {
        path: file_path.to_string(),
        message: format!("无法读取文件元数据: {}", e),
    })?;

    if metadata.len() > MAX_FILE_SIZE {
        return Err(ParserError::SecurityError(format!(
            "文件大小超出限制（最大 {} MB）",
            MAX_FILE_SIZE / 1024 / 1024
        )));
    }

    Ok(canonical_path.to_string_lossy().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_validate_path_securely_with_valid_path() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.txt");
        std::fs::write(&test_file, "test").unwrap();

        let result = validate_path_securely(
            test_file.to_str().unwrap(),
            temp_dir.path().to_str().unwrap(),
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_path_securely_with_path_traversal() {
        let temp_dir = TempDir::new().unwrap();

        // 使用路径遍历攻击尝试访问父目录
        let malicious_path = format!(
            "{}\\..\\..\\windows\\system32\\config\\sam",
            temp_dir.path().display()
        );

        let result = validate_path_securely(&malicious_path, temp_dir.path().to_str().unwrap());

        // 在 Windows 上应该检测到路径遍历攻击或者文件不存在
        assert!(result.is_err());
        let err = result.unwrap_err();
        assert!(
            matches!(
                err,
                ParserError::SecurityError(_) | ParserError::FileNotFound { .. }
            ),
            "Expected SecurityError or FileNotFound, got: {:?}",
            err
        );
    }

    #[test]
    fn test_validate_path_securely_with_null_byte() {
        let temp_dir = TempDir::new().unwrap();
        let malicious_path = format!("{}/../../../etc/passwd\0", temp_dir.path().display());

        let result = validate_path_securely(&malicious_path, temp_dir.path().to_str().unwrap());

        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), ParserError::SecurityError(_)));
    }
}
