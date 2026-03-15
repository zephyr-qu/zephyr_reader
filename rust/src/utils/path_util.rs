//! 路径工具函数

use std::path::{Path, PathBuf};

/// 获取文件扩展名（小写）
pub fn get_file_extension(file_path: &str) -> Option<String> {
    Path::new(file_path)
        .extension()
        .and_then(|ext| ext.to_str())
        .map(|s| s.to_lowercase())
}

/// 获取文件名（不含扩展名）
pub fn get_file_name_without_extension(file_path: &str) -> Option<String> {
    Path::new(file_path)
        .file_stem()
        .and_then(|s| s.to_str())
        .map(|s| s.to_string())
}

/// 获取完整文件名（含扩展名）
pub fn get_file_name(file_path: &str) -> Option<String> {
    Path::new(file_path)
        .file_name()
        .and_then(|s| s.to_str())
        .map(|s| s.to_string())
}

/// 获取文件所在目录
pub fn get_parent_dir(file_path: &str) -> Option<PathBuf> {
    Path::new(file_path).parent().map(|p| p.to_path_buf())
}

/// 判断文件是否存在
pub fn file_exists(file_path: &str) -> bool {
    Path::new(file_path).exists()
}

/// 判断是否为目录
pub fn is_directory(path: &str) -> bool {
    Path::new(path).is_dir()
}

/// 判断是否为文件
pub fn is_file(path: &str) -> bool {
    Path::new(path).is_file()
}

/// 规范化路径
pub fn normalize_path(path: &str) -> String {
    Path::new(path)
        .canonicalize()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
        .unwrap_or_else(|| path.to_string())
}

/// 组合路径
pub fn join_path(base: &str, path: &str) -> String {
    Path::new(base).join(path).to_string_lossy().to_string()
}

/// 获取绝对路径
pub fn get_absolute_path(path: &str) -> Option<String> {
    Path::new(path)
        .canonicalize()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
}

/// 检查路径是否在指定目录内
pub fn is_path_in_dir(file_path: &str, dir_path: &str) -> bool {
    if let (Ok(file), Ok(dir)) = (
        Path::new(file_path).canonicalize(),
        Path::new(dir_path).canonicalize(),
    ) {
        file.starts_with(dir)
    } else {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_file_extension() {
        assert_eq!(get_file_extension("test.txt"), Some("txt".to_string()));
        assert_eq!(get_file_extension("test.EPUB"), Some("epub".to_string()));
        assert_eq!(get_file_extension("no_extension"), None);
    }

    #[test]
    fn test_get_file_name() {
        assert_eq!(
            get_file_name("/path/to/file.txt"),
            Some("file.txt".to_string())
        );
        assert_eq!(
            get_file_name_without_extension("/path/to/file.txt"),
            Some("file".to_string())
        );
    }

    #[test]
    fn test_file_exists() {
        assert!(!file_exists("non_existent_file.txt"));
    }
}
