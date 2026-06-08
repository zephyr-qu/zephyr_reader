//! 工具模块纯函数单元测试

use rust_lib_zephyr_reader::utils::security::{validate_file_path, validate_file_path_async};

mod common;

// ==================== validate_file_path ====================

#[test]
fn test_validate_valid_file() {
    let (_tmp, path) = common::create_temp_file("test_utils_valid.txt", "hello");
    let result = validate_file_path(&path);
    assert!(result.is_ok(), "expected Ok, got {:?}", result);
    let canonical = result.unwrap();
    assert!(
        canonical.contains("test_utils_valid.txt"),
        "canonical path should contain filename"
    );
}

#[test]
fn test_validate_nonexistent_path() {
    let result = validate_file_path("/nonexistent/path/foo.txt");
    assert!(result.is_err(), "expected Err for non-existent path");
    let err = result.unwrap_err();
    assert!(
        matches!(
            err,
            rust_lib_zephyr_reader::domain::AppError::FileNotFound { .. }
        ),
        "expected FileNotFound, got {:?}",
        err
    );
}

#[test]
fn test_validate_directory() {
    let dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let dir_path = dir.path().to_str().unwrap().to_string();
    let result = validate_file_path(&dir_path);
    assert!(result.is_err(), "expected Err for directory path");
    let err = result.unwrap_err();
    let msg = err.to_string();
    assert!(
        msg.contains("not a file") || msg.contains("is a directory"),
        "expected message about not being a file, got: {}",
        msg
    );
}

// ==================== validate_file_path_async ====================

#[tokio::test]
async fn test_validate_async_valid_file() {
    let (_tmp, path) = common::create_temp_file("test_utils_async_valid.txt", "async data");
    let result = validate_file_path_async(&path).await;
    assert!(result.is_ok(), "expected Ok, got {:?}", result);
    let canonical = result.unwrap();
    assert!(
        canonical.contains("test_utils_async_valid.txt"),
        "canonical path should contain filename"
    );
}

#[tokio::test]
async fn test_validate_async_nonexistent() {
    let result = validate_file_path_async("/nonexistent/path/async_foo.txt").await;
    assert!(result.is_err(), "expected Err for non-existent path");
    let err = result.unwrap_err();
    assert!(
        matches!(
            err,
            rust_lib_zephyr_reader::domain::AppError::FileNotFound { .. }
        ),
        "expected FileNotFound, got {:?}",
        err
    );
}

#[tokio::test]
async fn test_validate_async_directory() {
    let dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let dir_path = dir.path().to_str().unwrap().to_string();
    let result = validate_file_path_async(&dir_path).await;
    assert!(result.is_err(), "expected Err for directory path");
    let err = result.unwrap_err();
    let msg = err.to_string();
    assert!(
        msg.contains("not a file") || msg.contains("is a directory"),
        "expected message about not being a file, got: {}",
        msg
    );
}
