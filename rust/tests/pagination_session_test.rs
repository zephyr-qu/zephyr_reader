//! Pagination session handle API integration tests.

mod common;

use rust_lib_zephyr_reader::api::core::{
    create_pagination_session, dispose_pagination_session, get_session_page_content,
    paginate_session_full,
};
use rust_lib_zephyr_reader::domain::TypesetConfig;

async fn setup_parsed_txt_book(content: &str) -> (tempfile::TempDir, String) {
    common::init_logger();
    let temp_dir = tempfile::TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    if let Err(e) = rust_lib_zephyr_reader::api::data::init::init_storage(data_dir).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {e}");
        }
    }

    let file_path = temp_dir.path().join("session_book.txt");
    std::fs::write(&file_path, content).expect("failed to write test file");
    let file_path = file_path.to_string_lossy().to_string();

    rust_lib_zephyr_reader::api::core::parse_book(file_path.clone())
        .await
        .expect("parse_book should succeed");

    (temp_dir, file_path)
}

#[tokio::test]
async fn test_create_session_and_get_page_content() {
    let content = "Line one.\nLine two.\nLine three.\nLine four.\nLine five.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();

    let (handle, result) = create_pagination_session(
        file_path.clone(),
        0,
        config,
        None,
    )
    .await
    .expect("create_pagination_session should succeed");

    assert!(handle.session_id > 0);
    assert!(!result.descriptors.is_empty(), "should produce page descriptors");

    let page_text = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");
    assert!(!page_text.is_empty(), "first page should have content");

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn test_paginate_session_full_upgrades_partial() {
    let content: String = (0..200)
        .map(|i| format!("Paragraph {i}. Some filler text for pagination.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let config = TypesetConfig::default();

    let (handle, partial) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        Some(500),
    )
    .await
    .expect("partial create should succeed");
    assert!(partial.is_partial);

    let full = paginate_session_full(handle.clone())
        .await
        .expect("paginate_session_full should succeed");
    assert!(!full.is_partial);
    assert!(
        full.descriptors.len() >= partial.descriptors.len(),
        "full pagination should not shrink page count"
    );

    let page_text = get_session_page_content(handle.clone(), 0)
        .expect("page fetch after full pagination should succeed");
    assert!(!page_text.is_empty());

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn test_dispose_unknown_session_returns_not_found() {
    use rust_lib_zephyr_reader::api::core::PaginationSessionHandle;

    let err = dispose_pagination_session(PaginationSessionHandle {
        session_id: u64::MAX,
    })
    .expect_err("unknown session should fail");
    assert!(
        err.to_string().contains("pagination session"),
        "expected NotFound, got: {err}"
    );
}

#[tokio::test]
async fn test_get_page_content_after_dispose_returns_not_found() {
    let content = "Short chapter text.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();

    let (handle, _) = create_pagination_session(file_path, 0, config, None)
        .await
        .expect("create should succeed");
    dispose_pagination_session(handle.clone()).expect("dispose should succeed");

    let err = get_session_page_content(handle, 0).expect_err("disposed session should fail");
    assert!(
        err.to_string().contains("pagination session"),
        "expected NotFound, got: {err}"
    );
}
