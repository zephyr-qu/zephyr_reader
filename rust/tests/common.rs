//! 测试辅助模块
//! 提供通用的测试工具函数
//!
//! 注意：这些函数当前未被使用，但保留用于未来的扩展测试。

#![allow(dead_code)]

use std::path::PathBuf;

/// 获取测试资源目录
pub fn get_test_resources_dir() -> PathBuf {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap_or_else(|_| ".".to_string());
    PathBuf::from(manifest_dir).join("test_resources")
}

/// 创建临时测试文件
pub fn create_temp_file(content: &str, extension: &str) -> PathBuf {
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    let temp_dir = std::env::temp_dir();
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis();

    let file_name = format!("test_{}.{}", timestamp, extension);
    let file_path = temp_dir.join(&file_name);

    fs::write(&file_path, content).expect("Failed to create temp file");
    file_path
}

/// 清理临时测试文件
pub fn cleanup_temp_file(file_path: &PathBuf) {
    std::fs::remove_file(file_path).ok();
}

/// 测试用的 EPUB 文件路径（如果存在）
pub fn get_sample_epub_path() -> Option<PathBuf> {
    let resources = get_test_resources_dir();
    let epub_path = resources.join("sample.epub");

    if epub_path.exists() {
        Some(epub_path)
    } else {
        None
    }
}

/// 测试用的 TXT 文件路径（如果存在）
pub fn get_sample_txt_path() -> Option<PathBuf> {
    let resources = get_test_resources_dir();
    let txt_path = resources.join("sample.txt");

    if txt_path.exists() {
        Some(txt_path)
    } else {
        None
    }
}
