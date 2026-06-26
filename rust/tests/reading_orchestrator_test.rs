//! ReadingOrchestrator integration tests — ported from core.rs::tests.
//!
//! These tests exercise the FFI-level chapter-read and pagination API through
//! the public surface (api::core::*), verifying that the extraction in Phase 4
//! preserved all behavior bit-for-bit.

mod common;

use std::path::PathBuf;
use std::sync::LazyLock;

use rust_lib_zephyr_reader::api::core::{
    get_chapter, get_chapter_partial, paginate_chapter,
    paginate_all_content, parse_book, supports_chunked_pagination, ChapterContent,
};
use rust_lib_zephyr_reader::api::data::init::init_storage;
use rust_lib_zephyr_reader::domain::{AppError, TypesetConfig};
use rust_lib_zephyr_reader::reading::chapter_access::format_from_file_path;
use rust_lib_zephyr_reader::reading::orchestrator::ReadingOrchestrator;
use rust_lib_zephyr_reader::storage::{
    storage_pool, models::BookFormat, repos::{BookRepository, ChapterRepository},
};
use tempfile::TempDir;

/// Shared temp dir for all storage-dependent tests — stays alive for the process.
static SHARED_DIR: LazyLock<TempDir> = LazyLock::new(|| {
    TempDir::new().expect("failed to create shared temp dir")
});

/// Initialize STORAGE exactly once, using the shared temp dir.
async fn ensure_shared_storage() {
    use tokio::sync::Mutex;
    static INIT: Mutex<bool> = Mutex::const_new(false);
    let mut done = INIT.lock().await;
    if *done {
        return;
    }
    *done = true;
    if let Err(e) = init_storage(SHARED_DIR.path().to_string_lossy().to_string()).await {
        // 存储可能已被同一进程的其他测试共享全局初始化
        eprintln!("init_storage note (tolerated): {e}");
    }
}

#[test]
fn test_format_from_file_path() {
    assert_eq!(format_from_file_path("book.txt"), Ok(BookFormat::Txt));
    assert_eq!(format_from_file_path("book.epub"), Ok(BookFormat::Epub));
    assert!(format_from_file_path("book.md").is_err());
    assert!(format_from_file_path("book.pdf").is_err());
    assert!(format_from_file_path("book.markdown").is_err());
    assert_eq!(
        format_from_file_path("book.mobi"),
        Err(AppError::UnsupportedFormat { format: "Unknown format: mobi".into() })
    );
    assert_eq!(
        format_from_file_path("book_no_ext"),
        Err(AppError::UnsupportedFormat { format: "file has no extension".into() })
    );
}

#[test]
fn test_supports_chunked_pagination() {
    assert!(supports_chunked_pagination("book.txt".to_string()));
    assert!(supports_chunked_pagination("book.epub".to_string()));
    assert!(!supports_chunked_pagination("book.pdf".to_string()));
    assert!(!supports_chunked_pagination("book.md".to_string()));
}

#[tokio::test]
async fn diagnose_content_extraction_pipeline() {
    common::init_test_storage().await;
    let content = "第一章 混合内容\n\nToday was the day. 他站在窗前。\n";
    let file_path_buf = SHARED_DIR.path().join("test_book_diag.txt");
    std::fs::write(&file_path_buf, content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    let pool = storage_pool().unwrap();
    let _book = BookRepository::find_by_id(&pool, &book_id).await
        .expect("find_by_id should succeed")
        .expect("book should exist");
    let _chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");

    // Use get_chapter (the user-facing API) instead of get_or_create_provider (private)
    let chapter = get_chapter(file_path.clone(), 0, None).await
        .expect("get_chapter should succeed");
    match &chapter {
        ChapterContent::Raw(text) => {
            assert!(!text.is_empty(), "Content extraction should return non-empty text");
        }
        ChapterContent::Pages(_) => {}
    }

    let config = TypesetConfig::default();
    let pages = paginate_all_content(file_path.clone(), 0, config).await
        .expect("paginate_all_content should succeed");

    assert!(!pages.is_empty(), "PaginateAllContent should produce at least 1 page");
}

#[tokio::test]
async fn test_paginate_chapter_cache_hit_roundtrip() {
    ensure_shared_storage().await;
    let content = "第一章 测试内容\n\nThis is a test chapter for cache roundtrip.\n我们来测试缓存是否正常工作。";
    let file_path_buf = SHARED_DIR.path().join("test_cache_hit.txt");
    std::fs::write(&file_path_buf, content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    parse_book(file_path.clone()).await
        .expect("parse_book should succeed");

    let config = TypesetConfig::default();

    // First call: cache MISS, should compute and save to KV
    let result1 = paginate_chapter(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("paginate_chapter should succeed (MISS)");
    assert!(!result1.is_partial, "full chapter should not be partial");
    assert!(!result1.descriptors.is_empty(), "should have at least 1 page");

    // Second call: cache HIT, should return immediately from KV
    let result2 = paginate_chapter(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("paginate_chapter should succeed (HIT)");

    assert_eq!(
        result1.descriptors, result2.descriptors,
        "cache HIT should return same descriptors as MISS"
    );
    assert_eq!(result1.config_hash, result2.config_hash,
        "same config should produce same hash");
}

#[tokio::test]
async fn test_paginate_chapter_config_change_misses_cache() {
    ensure_shared_storage().await;
    let content = "Different config test content 不同配置测试\nThis should produce different pagination.";
    let file_path_buf = SHARED_DIR.path().join("test_config_miss.txt");
    std::fs::write(&file_path_buf, content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    parse_book(file_path.clone()).await
        .expect("parse_book should succeed");

    let config1 = TypesetConfig::default();

    // First call with default config (populates KV cache)
    paginate_chapter(
        file_path.clone(), 0, config1.clone(), None,
    ).await.expect("first paginate should succeed");

    // Second call with different font_size → different config_hash → MISS
    let mut config2 = TypesetConfig::default();
    config2.font_size = config2.font_size + 8;
    let result2 = paginate_chapter(
        file_path.clone(), 0, config2.clone(), None,
    ).await.expect("second paginate (diff config) should succeed");

    assert_ne!(result2.config_hash, config1.config_hash(),
        "different config should produce different hash");
}

#[tokio::test]
async fn test_paginate_chapter_partial_skips_full_cache() {
    ensure_shared_storage().await;
    let content = "Partial cache test. This is a longer text that should have enough content for partial pagination. 部分缓存测试内容用来验证跳过全章缓存逻辑。";
    let file_path_buf = SHARED_DIR.path().join("test_partial_skip.txt");
    std::fs::write(&file_path_buf, content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    parse_book(file_path.clone()).await
        .expect("parse_book should succeed");

    let config = TypesetConfig::default();

    // First do full paginate to populate KV cache
    paginate_chapter(
        file_path.clone(), 0, config.clone(), None,
    ).await.expect("full paginate should succeed");

    // Partial paginate should NOT read from full KV cache
    let partial_result = paginate_chapter(
        file_path.clone(), 0, config.clone(), Some(15),
    ).await.expect("partial paginate should succeed");

    assert!(partial_result.is_partial, "partial pagination should be marked partial");
    assert!(!partial_result.descriptors.is_empty(), "partial paginate should still produce pages");
}

#[tokio::test]
async fn test_stale_epub_bounds_returns_stale_book_data() {
    ensure_shared_storage().await;
    // Use a unique copy so parallel tests don't share the same DB row
    let unique_path = SHARED_DIR.path().join("test_stale_bounds.epub");
    std::fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/fixtures/medium.epub"),
        &unique_path,
    ).expect("copy fixture");
    let file_path = unique_path.to_string_lossy().to_string();

    // Parse EPUB to populate DB with valid chapter data
    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");

    // Corrupt the first chapter's bounds to simulate stale pre-migration data
    let pool = storage_pool().unwrap();
    let mut chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");
    assert!(!chapters.is_empty(), "EPUB fixture should have at least one chapter");

    chapters[0].start_index = 0;
    chapters[0].end_index = 0;
    ChapterRepository::save(&pool, &book_id, &chapters[..1]).await
        .expect("save corrupted chapter should succeed");

    // Clear caches for a clean slate
    ReadingOrchestrator::global().clear_caches_for_test();

    // get_chapter internally calls get_or_create_provider which should detect stale data
    let result = get_chapter(file_path.clone(), 0, None).await;
    assert!(result.as_ref().is_err_and(|e| matches!(e, AppError::StaleBookData { .. })),
        "expected StaleBookData, got {:?}", result.as_ref().err());
}

#[tokio::test]
async fn test_get_chapter_epub_uses_db_bounds() {
    ensure_shared_storage().await;
    // Use a unique copy so parallel tests don't share the same DB row
    let unique_path = SHARED_DIR.path().join("test_db_bounds.epub");
    std::fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/fixtures/medium.epub"),
        &unique_path,
    ).expect("copy fixture");
    let file_path = unique_path.to_string_lossy().to_string();

    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    let pool = storage_pool().unwrap();
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");
    assert!(chapters.len() >= 2, "medium.epub should have ≥2 chapters");

    let ch0 = &chapters[0];
    let ch1 = &chapters[1];
    // ch0 spine range must not overlap ch1's
    assert!(ch0.end_index <= ch1.start_index,
        "chapters should have non-overlapping spine ranges, \
         ch0.end={} ch1.start={}", ch0.end_index, ch1.start_index);
    // Pre-fix bug: get_chapter returned full EPUB content for ANY chapter
    // because spine indices were treated as byte offsets.  The 3-byte
    // garbage from `read_text_range(0, 3)` happened to differ between
    // chapters, so the old `ch0_text != ch1_text` assertion was a false
    // positive — it passed even with broken code.
    //
    // Strengthened: assert each chapter returns > 100 chars of content
    // (not 3 bytes), so the test catches the pre-fix regression.  The
    // `test_get_chapter_epub_returns_full_chapter_content` test
    // (Plan A regression) also covers this for ch0; here we add the
    // assertion for ch1 and the `ch0_text != ch1_text` invariant.
    ReadingOrchestrator::global().clear_caches_for_test();
    let ch0_result = get_chapter(file_path.clone(), 0, None).await
        .expect("get_chapter ch0 should succeed");
    let ch1_result = get_chapter(file_path.clone(), 1, None).await
        .expect("get_chapter ch1 should succeed");
    if let (ChapterContent::Raw(ch0_text), ChapterContent::Raw(ch1_text)) =
        (&ch0_result, &ch1_result)
    {
        assert!(ch0_text.chars().count() > 100,
            "ch0 must return full chapter content (>100 chars), got {}",
            ch0_text.chars().count());
        assert!(ch1_text.chars().count() > 100,
            "ch1 must return full chapter content (>100 chars), got {}",
            ch1_text.chars().count());
        assert_ne!(ch0_text, ch1_text,
            "ch0 and ch1 should return different content per DB bounds");
    } else {
        panic!("expected ChapterContent::Raw, got Pages variant");
    }
}

#[tokio::test]
async fn test_get_chapter_partial_epub_uses_char_count() {
    ensure_shared_storage().await;
    let unique_path = SHARED_DIR.path().join("test_partial_epub.epub");
    std::fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/fixtures/medium.epub"),
        &unique_path,
    ).expect("copy fixture");
    let file_path = unique_path.to_string_lossy().to_string();
    let _ = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    ReadingOrchestrator::global().clear_caches_for_test();

    let partial = get_chapter_partial(file_path.clone(), 0, 100).await
        .expect("partial should succeed");
    let char_count = partial.chars().count();
    assert!(char_count <= 100,
        "partial should return ≤100 chars, got {char_count}");
    assert!(char_count > 0,
        "partial should return at least some content");
}

/// Regression test for CRITICAL BUG #1 (audited 2026-06-17):
/// `get_chapter` for EPUB must return the FULL chapter content, not just
/// the first 3 bytes. Before the fix, `get_chapter_bounds` returned spine
/// indices (e.g. (0, 3)) which were then passed to `read_text_range` as
/// byte offsets, silently truncating every EPUB chapter read.
#[tokio::test]
async fn test_get_chapter_epub_returns_full_chapter_content() {
    ensure_shared_storage().await;
    let unique_path = SHARED_DIR.path().join("test_epub_full_chapter.epub");
    std::fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/fixtures/medium.epub"),
        &unique_path,
    ).expect("copy fixture");
    let file_path = unique_path.to_string_lossy().to_string();

    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    let pool = storage_pool().unwrap();
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");
    assert!(!chapters.is_empty(), "EPUB fixture should have ≥1 chapter");

    ReadingOrchestrator::global().clear_caches_for_test();
    let result = get_chapter(file_path.clone(), 0, None).await
        .expect("get_chapter ch0 should succeed");
    if let ChapterContent::Raw(text) = &result {
        // Before the fix, this was ≤3 bytes. After the fix it must be a
        // full chapter — well over 100 chars.
        assert!(text.chars().count() > 100,
            "EPUB get_chapter must return full chapter content, got {} chars",
            text.chars().count());
    } else {
        panic!("expected ChapterContent::Raw, got Pages variant");
    }
}

/// Regression test for CRITICAL BUG #2 (audited 2026-06-17):
/// `paginate_chapter` partial mode for TXT must read from the chapter's
/// start byte offset, not from byte 0. Before the fix, partial pagination
/// for chapter_index > 0 returned the first 100 chars of the FILE (i.e.
/// chapter 0), regardless of the requested chapter.
#[tokio::test]
async fn test_paginate_chapter_partial_txt_uses_chapter_bounds() {
    ensure_shared_storage().await;
    // 3 chapters with distinct content. Use digit chapter markers so
    // chapter_index values are 0, 1, 2 (not Roman-numeral collisions).
    let ch0 = "1. First chapter content alpha alpha alpha.";
    let ch1 = "2. Second chapter content beta beta beta.";
    let ch2 = "3. Third chapter content gamma gamma gamma.";
    let content = format!("{ch0}\n{ch1}\n{ch2}\n");
    let file_path_buf = SHARED_DIR.path().join("test_partial_chapter_bounds.txt");
    std::fs::write(&file_path_buf, &content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    let pool = storage_pool().unwrap();
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");
    assert!(chapters.len() >= 3,
        "test fixture should produce ≥3 chapters, got {}", chapters.len());

    let last_chapter_idx = chapters.last().unwrap().chapter_index as i32;
    let first_chapter_idx = chapters.first().unwrap().chapter_index as i32;
    ReadingOrchestrator::global().clear_caches_for_test();

    let config = TypesetConfig::default();

    // Request partial pagination of the last chapter.
    let partial = paginate_chapter(
        file_path.clone(), last_chapter_idx, config.clone(), Some(60),
    ).await.expect("partial paginate of last chapter should succeed");

    assert!(partial.is_partial, "partial pagination should be marked partial");
    assert!(!partial.descriptors.is_empty(),
        "partial paginate of last chapter should produce ≥1 page, got {}",
        partial.descriptors.len());

    // Bug 2 fix verification: the partial paginate's first page must
    // contain content from the LAST chapter, not from chapter 0.  We
    // fetch the first page via get_page_content and assert it does not
    // leak any earlier-chapter content.
    use rust_lib_zephyr_reader::api::core::get_page_content;
    use rust_lib_zephyr_reader::utils::security::validate_file_path;
    let canonical_path = validate_file_path(&file_path)
        .expect("validate_file_path should succeed");
    let first_page_text = get_page_content(
        canonical_path.clone(), last_chapter_idx, partial.config_hash, 0,
    )
    .expect("get_page_content should succeed when streamer is cached");
    assert!(!first_page_text.is_empty(),
        "partial last-chapter first page should not be empty: got {first_page_text:?}");
    assert!(!first_page_text.contains("1. First chapter"),
        "partial last-chapter leaked ch0 content: {first_page_text:?}");
    assert!(!first_page_text.contains("2. Second chapter"),
        "partial last-chapter leaked ch1 content: {first_page_text:?}");
    assert!(first_page_text.contains("3. Third chapter"),
        "partial last-chapter should start with ch2: {first_page_text:?}");

    // Also verify get_chapter for the last chapter returns the right
    // content (the same bug existed there).
    let full = get_chapter(file_path.clone(), last_chapter_idx, None).await
        .expect("get_chapter last chapter should succeed");
    let full_text = match &full {
        ChapterContent::Raw(s) => s.clone(),
        ChapterContent::Pages(_) => panic!("expected Raw for last chapter, got Pages"),
    };
    assert!(full_text.chars().count() > 30,
        "get_chapter for last chapter must return content \
         (>30 chars), got {}", full_text.chars().count());
    assert!(!full_text.contains("1. First chapter"),
        "get_chapter last chapter must NOT contain ch0 marker: {full_text:?}");
    // Sanity check: first and last chapters are distinct (otherwise the
    // bug-2 check above is meaningless).
    assert_ne!(first_chapter_idx, last_chapter_idx,
        "first and last chapter should differ for a multi-chapter file");
}

/// Regression test for MEDIUM #8 (audited 2026-06-17):
/// `BOOK_ID_CACHE` previously never invalidated. If a user re-imports
/// the same file path with a different book (e.g. manual DB row reset
/// or content edit + reimport), the cache returns the stale book_id
/// and `find_by_index` misses, surfacing as `ChapterExtractError`.
///
/// After the fix, a `find_by_index` miss invalidates the cache and
/// the next call refetches via `find_by_file_path` automatically.
#[tokio::test]
async fn test_book_id_cache_invalidation_on_stale_miss() {
    use rust_lib_zephyr_reader::reading::book_id_cache;
    ensure_shared_storage().await;

    // Create a 2-chapter TXT file so the test has a meaningful chapter
    // structure to invalidate against.
    let content = "1. First chapter content.\n2. Second chapter content.\n";
    let file_path_buf = SHARED_DIR.path().join("test_book_id_cache_invalidation.txt");
    std::fs::write(&file_path_buf, content).unwrap();
    let file_path = file_path_buf.to_string_lossy().to_string();

    let book_id = parse_book(file_path.clone()).await
        .expect("parse_book should succeed");
    let pool = storage_pool().unwrap();
    let chapters = ChapterRepository::find_by_book(&pool, &book_id).await
        .expect("find_by_book should succeed");
    assert!(chapters.len() >= 2,
        "fixture must have ≥2 chapters, got {}", chapters.len());
    let first_chapter_idx = chapters.first().unwrap().chapter_index as i32;

    // 1. Populate BOOK_ID_CACHE by reading chapter bounds.
    ReadingOrchestrator::global().clear_caches_for_test();
    // BOOK_ID_CACHE key is the *canonical* path (post `validate_file_path`),
    // not the raw test path. Compute it once and reuse for all cache ops.
    let canonical_path = rust_lib_zephyr_reader::utils::security::validate_file_path(&file_path)
        .expect("validate_file_path");
    // Helper for bounds lookup via the FFI entry point.
    async fn get_bounds(
        path: &str, idx: i32,
    ) -> Result<(i32, i32), rust_lib_zephyr_reader::domain::AppError> {
        use rust_lib_zephyr_reader::utils::security::validate_file_path;
        let v = validate_file_path(path).map_err(|e|
            rust_lib_zephyr_reader::domain::AppError::FileReadError {
                path: path.to_string().into(),
                details: e.to_string().into(),
            })?;
        rust_lib_zephyr_reader::reading::chapter_access::get_chapter_bounds(&v, idx).await
    }
    let bounds1 = get_bounds(&file_path, first_chapter_idx).await
        .expect("first get_chapter_bounds should succeed");
    assert!(book_id_cache::BOOK_ID_CACHE.lock().contains(&canonical_path),
        "BOOK_ID_CACHE should be populated after successful lookup");

    // 2. Inject a STALE book_id into the cache (simulates reimport).
    let stale_book_id = "stale-book-id-does-not-exist-in-db";
    book_id_cache::BOOK_ID_CACHE.lock().put(canonical_path.clone(), stale_book_id.to_string());

    // 3. Call get_chapter_bounds again. Before the fix, this would
    // return `ChapterExtractError` (find_by_index("stale-book-id", 0)
    // misses). After the fix, the cache is invalidated and the call
    // succeeds via find_by_file_path.
    let bounds2 = get_bounds(&file_path, first_chapter_idx).await
        .expect("get_chapter_bounds with stale cache should auto-invalidate and succeed");
    assert_eq!(bounds1, bounds2,
        "bounds should match after cache invalidation refetch");

    // 4. Verify the cache now holds the FRESH book_id, not the stale one.
    let cached = book_id_cache::BOOK_ID_CACHE.lock().get(&canonical_path).cloned();
    assert_eq!(cached.as_deref(), Some(book_id.as_str()),
        "cache should be refilled with fresh book_id after invalidation");
    assert_ne!(cached.as_deref(), Some(stale_book_id),
        "cache must NOT still hold the stale book_id");
}

