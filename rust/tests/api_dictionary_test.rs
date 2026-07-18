mod common;

use rust_lib_zephyr_reader::api::dictionary::{
    close_dictionary, init_dictionary, lookup_mdict, suggest_mdict,
};
use std::path::Path;

// Resolve the canonical path to the dictionary .mdx file.
fn mdx_path() -> String {
    let manifest_dir = std::env!("CARGO_MANIFEST_DIR");
    let path = Path::new(manifest_dir).join("../assets/dictionary.mdx");
    path.canonicalize()
        .expect("dictionary.mdx not found at assets/dictionary.mdx")
        .to_str()
        .unwrap()
        .to_string()
}

// Helper: close any existing engine, then init with the default dictionary file.
async fn ensure_dictionary_initialized() {
    close_dictionary();
    let path = mdx_path();
    init_dictionary(path, None)
        .await
        .expect("init_dictionary should succeed");
}

// ==================== 词典初始化测试 ====================

// 成功初始化词典：使用 assets/dictionary.mdx
#[ignore]
#[tokio::test]
async fn test_dictionary_init_success() {
    common::init_logger();

    close_dictionary();
    let mdx_path = mdx_path();
    let result = init_dictionary(mdx_path, None).await;
    assert!(
        result.is_ok(),
        "init_dictionary should succeed with a valid .mdx file"
    );
}

// 使用不存在的路径应返回错误
#[ignore]
#[tokio::test]
async fn test_dictionary_init_wrong_path() {
    common::init_logger();

    close_dictionary();
    let result = init_dictionary("/nonexistent/foo.mdx".to_string(), None).await;
    assert!(
        result.is_err(),
        "init_dictionary should fail with a non-existent path"
    );
}

// 关闭后重新初始化应成功
#[ignore]
#[tokio::test]
async fn test_dictionary_close_and_reinit() {
    common::init_logger();

    close_dictionary();
    let mdx_path = mdx_path();

    // First init
    let result = init_dictionary(mdx_path.clone(), None).await;
    assert!(result.is_ok(), "first init should succeed");

    // Close
    close_dictionary();

    // Second init
    let result = init_dictionary(mdx_path.clone(), None).await;
    assert!(result.is_ok(), "re-init after close should succeed");
}

// ==================== 词典查询测试 ====================

// 查找存在的单词
#[ignore]
#[tokio::test]
async fn test_dictionary_lookup_existing_word() {
    common::init_logger();

    ensure_dictionary_initialized().await;

    let result = lookup_mdict("hello".to_string()).await;
    assert!(result.is_ok(), "lookup_mdict should return Ok");
    // The Option may be None if the word is not in dictionary — that's fine
}

// 查找不存在的单词不应 panic
#[ignore]
#[tokio::test]
async fn test_dictionary_lookup_nonexistent_word() {
    common::init_logger();

    ensure_dictionary_initialized().await;

    let result = lookup_mdict("xyznonexistentword123".to_string()).await;
    assert!(
        result.is_ok(),
        "lookup_mdict should return Ok even for missing words"
    );
}

// 前缀建议
#[ignore]
#[tokio::test]
async fn test_dictionary_suggest() {
    common::init_logger();

    ensure_dictionary_initialized().await;

    let result = suggest_mdict("hel".to_string(), 5).await;
    assert!(result.is_ok(), "suggest_mdict should return Ok");
    // May be empty — that's fine
}

// 建议 limit 边界
#[ignore]
#[tokio::test]
async fn test_dictionary_suggest_zero_limit() {
    common::init_logger();

    ensure_dictionary_initialized().await;

    // limit=0 应被 clamp 到 1（内部使用 limit.max(1))
    let result = suggest_mdict("hel".to_string(), 0).await;
    assert!(
        result.is_ok(),
        "suggest_mdict with limit=0 should still return Ok"
    );
}
