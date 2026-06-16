//! Pagination session handle API integration tests.

mod common;

use rust_lib_zephyr_reader::api::core::{
    create_pagination_session, dispose_pagination_session, get_session_page_content,
    paginate_session_full, repaginate_session,
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

    let full = paginate_session_full(handle.clone(), None)
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

#[tokio::test]
async fn test_dispose_evicts_streamer() {
    let content = "One.\nTwo.\nThree.\nFour.\nFive.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();
    let config_hash = config.config_hash();
    let validated_path =
        rust_lib_zephyr_reader::utils::security::validate_file_path(&file_path)
            .expect("validate should succeed");

    let (handle, _) = create_pagination_session(file_path, 0, config, None)
        .await
        .expect("create should succeed");

    // Session content available before dispose
    let session_page = get_session_page_content(handle.clone(), 0)
        .expect("session page should work before dispose");
    assert!(!session_page.is_empty(), "session page content should be available");

    // Streamer accessible via bare get_page_content before dispose
    let bare_before = rust_lib_zephyr_reader::api::core::get_page_content(
        validated_path.clone(),
        0,
        config_hash,
        0,
    );
    assert!(!bare_before.is_empty(), "bare get_page_content before dispose");

    let clone_before_dispose = handle.clone();
    dispose_pagination_session(handle).expect("dispose should succeed");

    // Session-level access fails after dispose
    let session_result = get_session_page_content(clone_before_dispose, 0);
    assert!(
        session_result.is_err(),
        "session page access should fail after dispose"
    );

    // STREAMER_CACHE entry evicted — bare get_page_content returns empty
    let bare_after = rust_lib_zephyr_reader::api::core::get_page_content(
        validated_path,
        0,
        config_hash,
        0,
    );
    assert!(
        bare_after.is_empty(),
        "bare get_page_content should return empty after dispose evicts streamer"
    );
}

#[tokio::test]
async fn test_repaginate_session_updates_descriptors_and_config() {
    let content: String = (0..200)
        .map(|i| format!("Paragraph {i}. Some filler text for pagination.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let mut config = TypesetConfig::default();
    config.font_size = 16;

    let (handle, initial) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        Some(2_000),
    )
    .await
    .expect("create should succeed");
    let initial_count = initial.descriptors.len();

    // Change font size → new config hash → new pagination
    config.font_size = 24;
    let repaginated = repaginate_session(handle.clone(), config, Some(2_000))
        .await
        .expect("repaginate should succeed");

    // Page count may change with new font size
    assert!(!repaginated.descriptors.is_empty());
    assert_ne!(initial.config_hash, repaginated.config_hash);

    // get_session_page_content still works after repaginate
    let page = get_session_page_content(handle.clone(), 0)
        .expect("page access after repaginate should succeed");
    assert!(!page.is_empty());

    // Dispose works normally
    dispose_pagination_session(handle).expect("dispose should succeed");
    // Suppress unused warning on initial_count when not asserted
    let _ = initial_count;
}

#[tokio::test]
async fn test_repaginate_session_partial_to_full_in_place() {
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

    // In-place expand to full — same config, no dispose
    let full = repaginate_session(handle.clone(), config, None)
        .await
        .expect("expand to full should succeed");
    assert!(!full.is_partial);
    assert!(full.descriptors.len() >= partial.descriptors.len());

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn test_repaginate_session_with_config_change_evicts_old_streamer() {
    let content: String = (0..200)
        .map(|i| format!("Paragraph {i}. Some filler text for pagination.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let validated_path =
        rust_lib_zephyr_reader::utils::security::validate_file_path(&file_path)
            .expect("validate should succeed");
    let mut config = TypesetConfig::default();
    let old_hash = config.config_hash();
    config.font_size = 12;

    let (handle, _) = create_pagination_session(file_path.clone(), 0, config.clone(), Some(2_000))
        .await
        .expect("create should succeed");

    // Change config and repaginate
    config.font_size = 24;
    let _ = repaginate_session(handle.clone(), config, Some(2_000))
        .await
        .expect("repaginate should succeed");

    // Old streamer should be evicted from STREAMER_CACHE
    let bare_old = rust_lib_zephyr_reader::api::core::get_page_content(
        validated_path,
        0,
        old_hash,
        0,
    );
    assert!(bare_old.is_empty(), "old streamer should be evicted");

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn test_repaginate_font_size_change_preserves_handle() {
    let content: String = (0..300)
        .map(|i| format!("Paragraph {i}. Some filler text for pagination test.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let mut config = TypesetConfig::default();
    config.font_size = 16;
    let initial_hash = config.config_hash();

    // Step 1: Create session at font_size=16
    let (handle, initial) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        Some(2_000),
    )
    .await
    .expect("initial create should succeed");
    let _initial_page_count = initial.descriptors.len();

    // Step 2: Change font_size to 20 and repaginate in place
    config.font_size = 20;
    let new_hash = config.config_hash();
    assert_ne!(initial_hash, new_hash, "font_size change should alter hash");

    let repaginated = repaginate_session(handle.clone(), config, Some(2_000))
        .await
        .expect("repaginate should succeed");
    assert_eq!(
        repaginated.config_hash, new_hash,
        "repaginated result should carry new hash"
    );
    // 不同 font size 通常产生不同的页数或页边界；这里不强求具体差异，
    // 因为字体配置可能对短文本无显著影响。关键是 handle 仍然有效。

    // Step 3: get_session_page_content still works on the same handle
    let page0 = get_session_page_content(handle.clone(), 0)
        .expect("page 0 should be readable after repaginate");
    assert!(!page0.is_empty(), "page 0 content should not be empty");

    // Step 4: handle is still valid (not disposed)
    // get_session_page_content returns Err for out-of-range, but the handle
    // itself is still alive (we haven't disposed yet).
    let _ = get_session_page_content(handle.clone(), 1);
    // Step 5: dispose works normally
    dispose_pagination_session(handle).expect("dispose should succeed");
}
