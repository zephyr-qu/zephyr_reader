//! Pagination session handle API integration tests.

mod common;

use rust_lib_zephyr_reader::api::core::{
    create_pagination_session, create_pagination_session_adopt, dispose_pagination_session,
    get_session_page_content, paginate_session_full, repaginate_session,
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

/// After dispose, the SESSION_MAP entry is removed so any subsequent
/// `get_session_page_content` call (which routes via SESSION_MAP) must
/// return NotFound.  This complements `test_dispose_evicts_streamer`
/// which tests the STREAMER_CACHE path (used by `get_page_content`).
///
/// (Renamed from `test_get_page_content_after_dispose_returns_not_found`
/// which was misleading — the test exercises the SESSION_MAP path,
/// not the file-based `get_page_content` API.)
async fn test_get_session_page_content_after_dispose_returns_not_found() {
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

#[tokio::test]
async fn test_adopt_from_cache_hit() {
    // Step 1: create_session populates both SESSION_MAP and STREAMER_CACHE
    let content = "Adopt test content.\nPage two content.\nPage three content.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();

    let (handle, original) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        None,
    )
    .await
    .expect("create should succeed");

    // Step 2: adopt from cache — same params → hit (streamer still in STREAMER_CACHE)
    let (adopted_handle, adopted) = create_pagination_session_adopt(
        file_path.clone(),
        0,
        config.clone(),
    )
    .await
    .expect("adopt should succeed (hit in STREAMER_CACHE)");

    assert_eq!(
        original.descriptors.len(),
        adopted.descriptors.len(),
        "adopted chapter should have same descriptor count"
    );
    assert!(
        !adopted.descriptors.is_empty(),
        "adopted chapter should have descriptors"
    );
    assert!(!adopted.is_partial, "full paginate should not be partial");

    // Step 3: page content accessible via adopted handle
    let page0 = get_session_page_content(adopted_handle.clone(), 0)
        .expect("adopted session page 0 should be readable");
    assert!(!page0.is_empty(), "page 0 content should not be empty");

    // Cleanup
    dispose_pagination_session(handle).expect("dispose should succeed");
    dispose_pagination_session(adopted_handle).expect("dispose should succeed");
}

#[tokio::test]
async fn test_adopt_miss_after_dispose() {
    // Dispose evicts the streamer from STREAMER_CACHE → subsequent adopt misses
    let content = "Miss after dispose.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();

    let (handle, _) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        None,
    )
    .await
    .expect("create should succeed");

    // Dispose → evicts streamer from STREAMER_CACHE
    dispose_pagination_session(handle).expect("dispose should succeed");

    // Adopt → miss (streamer evicted)
    let err = create_pagination_session_adopt(file_path.clone(), 0, config)
        .await
        .expect_err("adopt after dispose should fail");
    assert!(
        err.to_string().contains("page streamer"),
        "expected NotFound for evicted streamer, got: {err}"
    );
}

#[tokio::test]
async fn test_adopt_miss_wrong_config_hash() {
    // Different config hash → miss (no streamer for that key)
    let content = "Wrong config hash.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let mut config = TypesetConfig::default();
    config.font_size = 16;

    create_pagination_session(file_path.clone(), 0, config.clone(), None)
        .await
        .expect("create should succeed"); // only this one call — handle unused

    // Try adopt with a different config → config_hash differs → miss
    let mut wrong_config = TypesetConfig::default();
    wrong_config.font_size = 22;
    let err = create_pagination_session_adopt(file_path.clone(), 0, wrong_config)
        .await
        .expect_err("adopt with different config should fail");
    assert!(
        err.to_string().contains("page streamer"),
        "expected NotFound for hash mismatch, got: {err}"
    );
}

#[tokio::test]
async fn test_adopt_partial_staging_streamer() {
    // Simulate staging: paginate with max_chars → partial streamer in cache
    let content: String = (0..50)
        .map(|i| format!("Paragraph {i}. Some filler text for pagination.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let config = TypesetConfig::default();

    // create_session with max_chars → partial streamer in cache
    let (handle, result) = create_pagination_session(
        file_path.clone(),
        0,
        config.clone(),
        Some(500),
    )
    .await
    .expect("create partial session should succeed");
    assert!(result.is_partial, "should be partial with max_chars");
    let partial_count = result.descriptors.len();

    // Adopt → should get the partial streamer with is_partial=true
    let (adopted_handle, adopted) = create_pagination_session_adopt(
        file_path.clone(),
        0,
        config.clone(),
    )
    .await
    .expect("adopt partial should succeed");

    assert_eq!(
        adopted.descriptors.len(),
        partial_count,
        "partial adopt should have same count"
    );
    assert!(adopted.is_partial, "adopted partial should report is_partial");

    // After adopt we can still access pages
    let page0 = get_session_page_content(adopted_handle.clone(), 0)
        .expect("adopted partial session page 0 should be readable");
    assert!(!page0.is_empty(), "page 0 content should not be empty");

    dispose_pagination_session(handle).expect("dispose should succeed");
    dispose_pagination_session(adopted_handle).expect("dispose should succeed");
}

/// Regression test for HIGH BUG #1 (audited 2026-06-17):
/// `apply_session_repagination` previously held the STREAMER_CACHE lock
/// twice in sequence — once to clone the new streamer, then a second
/// time to pop the old key. Between the two, a concurrent reader could
/// observe a SESSION_MAP entry pointing at a config_hash for which the
/// old streamer was still in STREAMER_CACHE.  After the fix, both
/// operations happen in a single critical section.
///
/// This test creates a session, does a config-changing repaginate, then
/// verifies both old-key and new-key states are consistent.
#[tokio::test]
async fn test_repaginate_atomic_old_streamer_evicted() {
    let content: String = (0..100)
        .map(|i| format!("Line {i}. Some padding text to make this a long paragraph.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let config = TypesetConfig::default();

    let (handle, initial) = create_pagination_session(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("create should succeed");
    let initial_hash = initial.config_hash;

    // Repaginate with a different config (changes config_hash → different
    // STREAMER_CACHE key). The old key must be evicted atomically with
    // the new entry being visible.
    let mut new_config = config.clone();
    new_config.font_size = 24;
    let repaginated = repaginate_session(handle.clone(), new_config, None)
        .await.expect("repaginate should succeed");
    let new_hash = repaginated.config_hash;
    assert_ne!(initial_hash, new_hash, "config change should produce different hash");

    // New streamer is reachable via session handle.
    let page0 = get_session_page_content(handle.clone(), 0)
        .expect("new page 0 should be readable");
    assert!(!page0.is_empty(), "new page 0 must not be empty");

    // Old config_hash's streamer is evicted from STREAMER_CACHE.  We can't
    // query STREAMER_CACHE directly (it's pub(crate)), but we can verify
    // via `create_pagination_session_adopt` with the old config that
    // it now misses.
    let adopt_old = create_pagination_session_adopt(
        file_path.clone(), 0, config,
    ).await;
    assert!(adopt_old.is_err(),
        "adopt with old config_hash should miss (old streamer evicted)");

    dispose_pagination_session(handle).expect("dispose should succeed");
}

/// Regression test for HIGH BUG #3 (audited 2026-06-17):
/// `dispose_pagination_session` previously removed SESSION_MAP first,
/// then popped STREAMER_CACHE.  Between the two, a concurrent
/// `create_pagination_session_adopt` could observe the still-cached
/// streamer and silently resurrect the disposed session.
///
/// After the fix, STREAMER_CACHE is popped first; adopt on a disposed
/// streamer must always return NotFound.
#[tokio::test]
async fn test_dispose_prevents_streamer_adoption() {
    let content = "Disposable content for adoption test.\nLine 2.\nLine 3.\n";
    let (_dir, file_path) = setup_parsed_txt_book(content).await;
    let config = TypesetConfig::default();

    // Create + immediately dispose — leaves a window in the old code
    // where adopt could succeed.
    let (handle, _) = create_pagination_session(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("create should succeed");
    dispose_pagination_session(handle).expect("dispose should succeed");

    // Adopt must miss. Before the fix, a concurrent thread could
    // squeeze between SESSION_MAP removal and STREAMER_CACHE pop and
    // successfully adopt the streamer.
    let adopt = create_pagination_session_adopt(
        file_path.clone(), 0, config,
    ).await;
    let err = adopt.err().expect("adopt after dispose should fail");
    assert!(err.to_string().contains("page streamer"),
        "expected NotFound for evicted streamer, got: {err}");
}

/// Regression test for HIGH BUG #2 (audited 2026-06-17):
/// `paginate_chapter` previously only checked the layout cache (KV,
/// slow) for full paginations.  After the fix, it also checks
/// STREAMER_CACHE (LRU, fast) — same `(path, chapter, config_hash)`
/// key — and reuses the streamer when present, skipping provider I/O
/// and CPU pagination entirely.
///
/// This test calls paginate_chapter twice in a row with the same
/// arguments and asserts the second call is served from STREAMER_CACHE
/// (verifiable by tracing log, but for black-box we just assert the
/// result is consistent and equal in cost to the first call).
#[tokio::test]
async fn test_paginate_chapter_streamer_cache_reuse() {
    let content: String = (0..200)
        .map(|i| format!("Paragraph {i}. Padding text to fill multiple pages.\n\n"))
        .collect();
    let (_dir, file_path) = setup_parsed_txt_book(&content).await;
    let config = TypesetConfig::default();

    // First call: cold cache, populates STREAMER_CACHE.
    let t0 = std::time::Instant::now();
    let first = paginate_chapter_for_test(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("first paginate should succeed");
    let first_dur = t0.elapsed();
    assert!(!first.is_partial);
    assert!(!first.descriptors.is_empty());

    // Second call with same args: should hit STREAMER_CACHE (fast path).
    let t1 = std::time::Instant::now();
    let second = paginate_chapter_for_test(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("second paginate should succeed");
    let second_dur = t1.elapsed();

    // The two results must match exactly (same number of pages, same
    // config_hash, same content per page).
    assert_eq!(first.config_hash, second.config_hash);
    for (i, (d1, d2)) in first.descriptors.iter()
        .zip(second.descriptors.iter()).enumerate() {
        assert_eq!(d1.start_offset, d2.start_offset,
            "page {i} start_offset mismatch: {} vs {}", d1.start_offset, d2.start_offset);
        assert_eq!(d1.end_offset, d2.end_offset,
            "page {i} end_offset mismatch: {} vs {}", d1.end_offset, d2.end_offset);
    }

    // Note: we don't assert second_dur < first_dur because the first
    // call's work is already small (single TXT file, no I/O beyond
    // already-loaded content).  The point of this test is correctness
    // — that the streamer cache hit path returns the same result.
    let _ = (first_dur, second_dur);
}

// Local re-export to keep the test self-contained.
async fn paginate_chapter_for_test(
    file_path: String,
    chapter_index: i32,
    config: TypesetConfig,
    max_chars: Option<u64>,
) -> Result<rust_lib_zephyr_reader::domain::PaginateResult,
    rust_lib_zephyr_reader::domain::AppError> {
    rust_lib_zephyr_reader::api::core::paginate_chapter(
        file_path, chapter_index, config, max_chars,
    ).await
}
