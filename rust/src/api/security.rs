//! 安全路径验证模块
//!
//! 提供严格的路径验证逻辑，防止路径遍历攻击、符号链接攻击等安全漏洞。

use std::path::{Path, PathBuf};
use crate::ffi::ParserError;

/// 验证文件路径是否安全
///
/// 确保文件路径在允许的基目录内，防止路径遍历攻击。
///
/// # 参数
///
/// * `file_path` - 待验证的文件路径
/// * `allowed_base` - 允许的基目录（如应用文档目录）
///
/// # 返回值
///
/// * `Ok(PathBuf)` - 验证通过的规范化路径
/// * `Err(ParserError)` - 路径不安全或无效
pub fn validate_path_securely(
    file_path: &str,
    allowed_base: &Path,
) -> Result<PathBuf, ParserError> {
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
        path_buf = allowed_base.join(path_buf);
    }

    // 3. 获取规范路径（解析符号链接）
    let canonical_path = path_buf
        .canonicalize()
        .map_err(|_| ParserError::FileNotFound {
            path: file_path.to_string(),
            reason: "文件不存在或无法访问".to_string(),
        })?;

    // 4. 获取规范的基目录
    let canonical_base = allowed_base
        .canonicalize()
        .map_err(|_| ParserError::ConfigError("基础目录无效".to_string()))?;

    // 5. 验证路径是否在允许的目录内
    if !canonical_path.starts_with(&canonical_base) {
        return Err(ParserError::SecurityError(
            format!(
                "路径遍历攻击检测：文件路径必须在 {} 目录内",
                canonical_base.display(),
            ),
        ));
    }

    // 6. 额外检查：Windows 系统检查危险路径
    #[cfg(windows)]
    {
        let path_str = canonical_path.to_string_lossy().to_lowercase();
        if path_str.starts_with(r"c:\windows")
            || path_str.starts_with(r"c:\program files")
            || path_str.starts_with(r"c:\programdata")
        {
            return Err(ParserError::SecurityError(
                "路径位于系统目录，禁止访问".to_string(),
            ));
        }
    }

    // 7. Unix 系统检查危险路径
    #[cfg(unix)]
    {
        let path_str = canonical_path.to_string_lossy();
        if path_str.starts_with("/etc/")
            || path_str.starts_with("/proc/")
            || path_str.starts_with("/sys/")
            || path_str.starts_with("/dev/")
        {
            return Err(ParserError::SecurityError(
                "路径位于系统目录，禁止访问".to_string(),
            ));
        }
    }

    Ok(canonical_path)
}

/// 检查是否为安全路径（简化版，向后兼容）
///
/// # 注意
///
/// 此函数仅进行基本检查，建议使用 `validate_path_securely` 进行严格验证。
pub fn is_safe_path(path: &str) -> bool {
    // 检查路径遍历攻击模式
    if path.contains("..\\") || path.contains("../") {
        return false;
    }

    // 检查绝对路径是否来自危险位置
    let path_lower = path.to_lowercase();
    if path_lower.starts_with("c:\\windows")
        || path_lower.starts_with("/etc/")
        || path_lower.starts_with("/proc/")
        || path_lower.starts_with("/sys/")
    {
        return false;
    }

    // 检查是否包含空字节（路径截断攻击）
    if path.contains('\0') {
        return false;
    }

    true
}

/// 验证文件路径并返回规范化的路径（向后兼容）
///
/// # 注意
///
/// 此函数使用简化的安全检查，建议使用 `validate_path_securely` 进行严格验证。
pub fn validate_file_path(file_path: &str) -> Result<String, ParserError> {
    if !is_safe_path(file_path) {
        return Err(ParserError::SecurityError(format!("文件路径不安全：{}", file_path)));
    }

    // 检查文件是否存在
    if !std::path::Path::new(file_path).exists() {
        return Err(ParserError::file_not_found(file_path));
    }

    Ok(file_path.to_string())
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
            temp_dir.path(),
        );

        assert!(result.is_ok());
    }

    #[test]
    fn test_validate_path_securely_with_path_traversal() {
        let temp_dir = TempDir::new().unwrap();
        let outside_file = "/etc/passwd";

        let result = validate_path_securely(outside_file, temp_dir.path());

        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), ParserError::SecurityError(_)));
    }

    #[test]
    fn test_validate_path_securely_with_null_byte() {
        let temp_dir = TempDir::new().unwrap();
        let malicious_path = format!("{}/../../../etc/passwd\0", temp_dir.path().display());

        let result = validate_path_securely(&malicious_path, temp_dir.path());

        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), ParserError::SecurityError(_)));
    }

    #[test]
    fn test_is_safe_path_basic() {
        // 基本安全检查
        assert!(!is_safe_path("../etc/passwd"));
        assert!(!is_safe_path("..\\windows\\system32"));
        assert!(!is_safe_path("/etc/passwd"));
        assert!(!is_safe_path("/proc/self"));
        assert!(!is_safe_path("test\0file.txt"));
        
        // 安全路径
        assert!(is_safe_path("/documents/book.txt"));
        assert!(is_safe_path("C:\\Users\\Documents\\book.txt"));
    }
}
