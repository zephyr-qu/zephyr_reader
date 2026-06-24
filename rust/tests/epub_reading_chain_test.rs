//! EPUB reading chain integration tests.
//!
//! Covers: `parse_book → provider → PageStreamer → PaginationSession`.
//! Mirrors the TXT `pagination_session_test.rs` structure so both paths can
//! be compared when debugging.
//!
//! Every test starts by checking for the required fixture file.  If it is
//! absent the test is skipped with a one-line message — no hard failure.

mod common;

use rust_lib_zephyr_reader::api::core::{
    create_pagination_session, paginate_session_full, repaginate_session,
    get_session_page_content, get_session_page_blocks, session_char_offset_to_page_index,
    dispose_pagination_session, get_chapter_first_spine_only,
    paginate_chapter, get_chapter, get_page_blocks, ChapterContent,
};
use rust_lib_zephyr_reader::domain::{AppError, ChapterPaginationMode, PageBlockSlice, TypesetConfig};
use rust_lib_zephyr_reader::storage::{storage_pool, repos::ChapterRepository};

use common::epub_local::require_fixture;
use common::reading_chain::{
    setup_parsed_epub, test_typeset_config, assert_monotonic_descriptors,
    assert_no_cross_page_duplicate, assert_partial_full_page0_stable,
};

// =========================================================================
// P0 — Critical regression net
// =========================================================================

#[tokio::test]
async fn epub_parse_and_session_baseline() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    let (handle, result) =
        create_pagination_session(file_path, 0, config, None)
            .await
            .expect("create_pagination_session should succeed");

    assert!(!result.descriptors.is_empty(), "descriptors should not be empty");
    assert!(!result.is_partial, "full chapter pagination should not be partial");

    let page0 = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");
    assert!(!page0.is_empty(), "page 0 should have content");

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_partial_to_full_upgrade() {
    let Some(path) = require_fixture("活着.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    // Create session with partial pagination (max_chars=500)
    let (handle, result) =
        create_pagination_session(file_path, 0, config.clone(), Some(500))
            .await
            .expect("partial session should succeed");
    assert!(result.is_partial, "should be partial with max_chars=500");
    let page0_partial = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");
    assert!(!page0_partial.is_empty(), "partial page 0 should have content");

    // Upgrade to full chapter
    let full = paginate_session_full(handle.clone(), None)
        .await
        .expect("paginate_session_full should succeed");
    assert!(!full.is_partial, "should not be partial after full upgrade");

    // Page 0 content must remain stable across the upgrade
    assert_partial_full_page0_stable(&handle, &page0_partial).await;

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_consecutive_pages_no_duplicate() {
    let Some(path) = require_fixture("活着.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    let (handle, result) =
        create_pagination_session(file_path, 0, config, None)
            .await
            .expect("session should succeed");

    let page_count = result.descriptors.len() as i32;
    let check_count = page_count.min(3);
    assert_no_cross_page_duplicate(&handle, check_count).await;

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_descriptors_monotonic_offsets() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    let (handle, result) =
        create_pagination_session(file_path, 0, config, None)
            .await
            .expect("session should succeed");

    assert_monotonic_descriptors(&result.descriptors);

    if let Some(last) = result.descriptors.last() {
        assert!(
            last.is_last_page,
            "last descriptor should have is_last_page=true"
        );
    }

    dispose_pagination_session(handle).expect("dispose should succeed");
}

// =========================================================================
// P1 — Reading chain completeness
// =========================================================================

#[tokio::test]
async fn epub_first_spine_matches_session_prefix() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    // Fetch the first-spine (fast path) text
    let spine = get_chapter_first_spine_only(file_path.clone(), 0)
        .await
        .expect("get_chapter_first_spine_only should succeed");
    assert!(!spine.text.is_empty(), "first spine text should not be empty");

    // Create full session and read page 0
    let (handle, _result) =
        create_pagination_session(file_path, 0, config, None)
            .await
            .expect("session should succeed");
    let page0 = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");

    // First-spine text and session page 0 should share the same first
    // meaningful line, even though the paginator adds `first_line_indent`
    // spacing that the raw spine extraction does not include.
    let spine_first = spine.text.lines().next().map(|l| l.trim()).unwrap_or("");
    let page_first = page0.lines().next().map(|l| l.trim()).unwrap_or("");
    assert!(!spine_first.is_empty(), "spine first line should be non-empty");
    assert_eq!(
        spine_first, page_first,
        "first non-empty line of spine text should match first line of page 0"
    );

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_repaginate_font_change() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config_small = test_typeset_config(); // font_size = 16

    let (handle, result) =
        create_pagination_session(file_path, 0, config_small.clone(), None)
            .await
            .expect("session should succeed");
    let original_hash = result.config_hash;
    let original_page0 = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");

    // Re-paginate with a larger font
    let config_large = TypesetConfig {
        font_size: 24,
        ..config_small
    };
    let repaginated = repaginate_session(handle.clone(), config_large, None)
        .await
        .expect("repaginate should succeed");

    assert_ne!(
        repaginated.config_hash, original_hash,
        "config_hash should change after font_size change"
    );
    let new_page0 = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");
    assert_ne!(
        new_page0, original_page0,
        "page 0 content should change after font_size change"
    );

    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_layout_cache_roundtrip() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    // First pagination — cache miss, actually computes pagination
    let r1 = paginate_chapter(file_path.clone(), 0, config.clone(), None)
        .await
        .expect("first paginate_chapter should succeed");

    // Second pagination with identical config — should hit the layout KV cache
    let r2 = paginate_chapter(file_path.clone(), 0, config, None)
        .await
        .expect("second paginate_chapter should succeed");

    assert_eq!(
        r1.descriptors, r2.descriptors,
        "layout cache roundtrip should produce identical descriptors",
    );
    assert_eq!(r1.config_hash, r2.config_hash);
}

#[tokio::test]
async fn epub_multi_chapter_index_1() {
    let Some(path) = require_fixture("活着.epub") else { return; };
    let (_dir, file_path, book_id) = setup_parsed_epub(&path).await;
    let config = test_typeset_config();

    // Chapter 1 (second chapter) should also be readable
    let (handle, result) =
        create_pagination_session(file_path, 1, config, None)
            .await
            .expect("chapter 1 session should succeed");
    assert!(
        !result.descriptors.is_empty(),
        "chapter 1 should have at least one descriptor"
    );

    let page0 = get_session_page_content(handle.clone(), 0)
        .expect("get_session_page_content should succeed");
    assert!(!page0.is_empty(), "chapter 1 page 0 should have content");

    // Verify DB bounds are sensible: start < end for non-empty chapters
    let pool = storage_pool().expect("storage_pool should be available");
    let chapters = ChapterRepository::find_by_book(&pool, &book_id)
        .await
        .expect("find_by_book should succeed");
    assert!(chapters.len() >= 2, "活着.epub should have ≥ 2 chapters");

    let ch0 = &chapters[0];
    let ch1 = &chapters[1];
    assert!(
        ch1.start_index < ch1.end_index,
        "chapter 1 should have start_index < end_index (start={}, end={})",
        ch1.start_index,
        ch1.end_index,
    );
    // Sanity: chapters should not overlap
    assert!(
        ch0.end_index <= ch1.start_index,
        "non-overlapping spine ranges: ch0.end={} ch1.start={}",
        ch0.end_index,
        ch1.start_index,
    );

    dispose_pagination_session(handle).expect("dispose should succeed");
}

// =========================================================================
// ADR-007 — Golden EPUB plain sample (`活着.epub` ch.0)
// =========================================================================

#[tokio::test]
async fn epub_golden_image_chapter_adr007_m55() {
    use rust_lib_zephyr_reader::parser::epub::get_chapter_content_ir;

    let Some(path) = require_fixture("活着.epub") else { return; };
    let (_dir, file_path, book_id) = setup_parsed_epub(&path).await;

    let pool = storage_pool().expect("storage_pool");
    let chapters = ChapterRepository::find_by_book(&pool, &book_id)
        .await
        .expect("chapters");
    assert!(!chapters.is_empty(), "活着.epub should have chapters");

    let mut image_chapter: Option<(i32, usize)> = None;
    for (idx, ch) in chapters.iter().enumerate() {
        let ir = get_chapter_content_ir(
            &file_path,
            ch.start_index as i32,
            ch.end_index as i32,
        )
        .expect("chapter IR should load");
        let count = ir.image_block_count();
        if count > 0 {
            image_chapter = Some((idx as i32, count));
            break;
        }
    }

    let Some((chapter_index, image_count)) = image_chapter else {
        eprintln!(
            "SKIP: 活着.epub has no Image blocks in any chapter (M5.5 needs a fixture with inline images)"
        );
        return;
    };

    let config = test_typeset_config();
    let result = paginate_chapter(file_path.clone(), chapter_index, config.clone(), None)
        .await
        .expect("paginate_chapter should succeed");

    assert_eq!(
        result.mode,
        ChapterPaginationMode::ContentBlocks,
        "chapter {chapter_index} with {image_count} image blocks must use block pagination"
    );
    assert!(!result.descriptors.is_empty());

    let blocks = get_page_blocks(
        file_path.clone(),
        chapter_index,
        result.config_hash,
        0,
    );
    assert!(
        blocks.iter().any(|b| matches!(b, PageBlockSlice::Image(_))),
        "first page of image chapter should expose Image block slice"
    );

    let (handle, _) = create_pagination_session(file_path, chapter_index, config, None)
        .await
        .expect("session adopt path should succeed");
    let offset_page = session_char_offset_to_page_index(handle.clone(), 0)
        .expect("charOffset 0 should resolve");
    assert_eq!(offset_page, 0);
    dispose_pagination_session(handle).expect("dispose should succeed");
}

#[tokio::test]
async fn epub_golden_plain_chapter0_adr007() {
    let Some(path) = require_fixture("活着.epub") else { return; };
    let (_dir, file_path, _book_id) = setup_parsed_epub(&path).await;

    let result = get_chapter(file_path, 0, None)
        .await
        .expect("get_chapter ch0 should succeed");
    let text = match result {
        ChapterContent::Raw(t) => t,
        _ => panic!("expected ChapterContent::Raw for EPUB ch0"),
    };

    let char_count = text.chars().count();
    assert!(
        char_count > 1000,
        "golden ch0 plain should be substantial, got {char_count} chars"
    );
    assert!(!text.contains('<'), "plain text must not leak HTML tags");
    assert!(
        text.contains("自序"),
        "golden marker: ch0 must contain 自序 (ADR-007 manual check)"
    );
    assert!(
        !text.contains("\n\n\n"),
        "plain must not have triple newlines"
    );
}

// =========================================================================
// M3 — Block pagination session (image EPUB)
// =========================================================================

#[tokio::test]
async fn epub_block_session_with_image() {
    use std::io::{Read, Write};
    use std::path::PathBuf;
    use zip::write::SimpleFileOptions;
    use zip::ZipWriter;

    let src_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../test/fixtures/medium.epub");
    if !src_path.exists() {
        eprintln!(
            "SKIP: missing fixture medium.epub at {}",
            src_path.display()
        );
        return;
    }

    let src_bytes = std::fs::read(&src_path).expect("read fixture");
    let src_zip = std::io::Cursor::new(src_bytes);
    let mut src_archive = zip::ZipArchive::new(src_zip).expect("open zip");

    let dir = tempfile::TempDir::new().expect("temp dir");
    let out_path = dir.path().join("with_image.epub");
    let out_file = std::fs::File::create(&out_path).expect("create out file");
    let mut out_zip = ZipWriter::new(out_file);

    let image_html = r#"<html xmlns="http://www.w3.org/1999/xhtml"><body>
<p>Before the picture.</p>
<img src="images/sample.jpg" alt="sample"/>
<p>After the picture.</p>
</body></html>"#;

    let mut names: Vec<String> = (0..src_archive.len())
        .map(|i| src_archive.by_index(i).unwrap().name().to_string())
        .collect();
    names.sort_by(|a, b| {
        if a == "mimetype" {
            std::cmp::Ordering::Less
        } else if b == "mimetype" {
            std::cmp::Ordering::Greater
        } else {
            a.cmp(b)
        }
    });

    for name in &names {
        let mut entry = src_archive.by_name(name).expect("entry in archive");
        let opts = if name == "mimetype" {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Stored)
                .unix_permissions(0o644)
        } else {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Deflated)
                .unix_permissions(0o644)
        };

        let is_chapter_spine =
            name.starts_with("OEBPS/chapter") && name.ends_with(".xhtml");

        if is_chapter_spine {
            out_zip
                .start_file(name, opts)
                .expect("start image spine entry");
            out_zip
                .write_all(image_html.as_bytes())
                .expect("write image spine");
        } else {
            let mut buf = Vec::new();
            entry.read_to_end(&mut buf).expect("read entry");
            out_zip.start_file(name, opts).expect("start entry");
            out_zip.write_all(&buf).expect("write entry");
        }
    }
    out_zip.finish().expect("finish zip");

    let data_dir = dir.path().join("storage");
    std::fs::create_dir_all(&data_dir).expect("create storage dir");
    rust_lib_zephyr_reader::api::data::init::init_storage(
        data_dir.to_string_lossy().to_string(),
    )
    .await
    .expect("init storage");

    let file_path = out_path.to_string_lossy().to_string();
    let book_id = rust_lib_zephyr_reader::api::core::parse_book(file_path.clone())
        .await
        .expect("parse_book should succeed");

    let pool = storage_pool().expect("storage_pool");
    let chapters = ChapterRepository::find_by_book(&pool, &book_id)
        .await
        .expect("chapters");
    let ch0 = &chapters[0];
    let ir = rust_lib_zephyr_reader::parser::epub::get_chapter_content_ir(
        &file_path,
        ch0.start_index as i32,
        ch0.end_index as i32,
    )
    .expect("chapter IR should load");
    assert!(
        ir.image_block_count() > 0,
        "fixture spine must produce Image blocks (count={})",
        ir.image_block_count()
    );

    let config = test_typeset_config();
    let (handle, result) = create_pagination_session(file_path, 0, config, None)
        .await
        .expect("create_pagination_session should succeed");

    assert_eq!(
        result.mode,
        ChapterPaginationMode::ContentBlocks,
        "chapters with images must use block pagination"
    );
    assert!(!result.descriptors.is_empty());

    let page_idx = session_char_offset_to_page_index(handle.clone(), 7)
        .expect("char offset on image placeholder should resolve");
    assert!(page_idx >= 0);

    let blocks = get_session_page_blocks(handle.clone(), page_idx)
        .expect("get_session_page_blocks should succeed");
    assert!(
        blocks.iter().any(|b| matches!(b, PageBlockSlice::Image(_))),
        "page with image should return Image block slice"
    );

    let plain = get_session_page_content(handle.clone(), page_idx)
        .expect("get_session_page_content should succeed");
    assert!(!plain.is_empty());

    dispose_pagination_session(handle).expect("dispose should succeed");
}

// =========================================================================
// P2 — Boundary / Migration from `core.rs` tests
// =========================================================================

#[tokio::test]
async fn epub_stale_bounds_returns_error() {
    let Some(path) = require_fixture("medium.epub") else { return; };
    let (_dir, file_path, book_id) = setup_parsed_epub(&path).await;

    let pool = storage_pool().expect("storage_pool should be available");
    let mut chapters = ChapterRepository::find_by_book(&pool, &book_id)
        .await
        .expect("find_by_book should succeed");
    assert!(!chapters.is_empty(), "medium.epub should have ≥ 1 chapter");

    // Corrupt the first chapter's bounds to simulate stale pre-migration data
    chapters[0].start_index = 0;
    chapters[0].end_index = 0;
    ChapterRepository::save(&pool, &book_id, &chapters[..1])
        .await
        .expect("save corrupted chapter should succeed");

    let config = test_typeset_config();
    let result = create_pagination_session(file_path, 0, config, None).await;

    assert!(
        result.as_ref().is_err_and(|e| matches!(e, AppError::StaleBookData { .. })),
        "expected StaleBookData error, got: {:?}",
        result.as_ref().err(),
    );
}

#[tokio::test]
async fn epub_chapter_too_large() {
    use std::io::{Read, Write};
    use zip::write::SimpleFileOptions;
    use zip::ZipWriter;
    use std::path::PathBuf;

    // Build an oversized EPUB at runtime: copy medium.epub but replace a spine
    // XHTML entry with content >2 MB.
    let src_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../test/fixtures/medium.epub");
    if !src_path.exists() {
        eprintln!(
            "SKIP: missing fixture medium.epub at {}",
            src_path.display()
        );
        return;
    }

    let src_bytes = std::fs::read(&src_path).expect("read fixture");
    let src_zip = std::io::Cursor::new(src_bytes);
    let mut src_archive = zip::ZipArchive::new(src_zip).expect("open zip");

    let dir = tempfile::TempDir::new().expect("temp dir");
    let out_path = dir.path().join("oversized.epub");
    let out_file = std::fs::File::create(&out_path).expect("create out file");
    let mut out_zip = ZipWriter::new(out_file);

    // Collect entry names; keep mimetype first (uncompressed, no extra data).
    let mut names: Vec<String> = (0..src_archive.len())
        .map(|i| src_archive.by_index(i).unwrap().name().to_string())
        .collect();
    names.sort_by(|a, b| {
        if a == "mimetype" {
            std::cmp::Ordering::Less
        } else if b == "mimetype" {
            std::cmp::Ordering::Greater
        } else {
            a.cmp(b)
        }
    });

    for name in &names {
        let mut entry = src_archive.by_name(name).expect("entry in archive");
        let opts = if name == "mimetype" {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Stored)
                .unix_permissions(0o644)
        } else {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Deflated)
                .unix_permissions(0o644)
        };

        let is_first_spine = name.contains("index_split_000")
            || name.contains("OEBPS/chapter_0")
            || name.ends_with(".xhtml") && !name.contains("toc");

        if is_first_spine {
            // Replace this spine with >2 MB of 'A' (the provider rejects
            // single spines larger than 2_000_000 bytes).
            let oversized = "A".repeat(2_100_000);
            out_zip
                .start_file(name, opts)
                .expect("start oversized entry");
            out_zip
                .write_all(oversized.as_bytes())
                .expect("write oversized content");
        } else {
            let mut buf = Vec::new();
            entry.read_to_end(&mut buf).expect("read entry");
            out_zip
                .start_file(name, opts)
                .expect("start entry");
            out_zip.write_all(&buf).expect("write entry");
        }
    }

    out_zip.finish().expect("finish zip");

    let oversized_path = out_path.to_string_lossy().to_string();

    // set up storage (separate from the fixture copy above)
    let data_dir = dir.path().join("storage");
    std::fs::create_dir_all(&data_dir).expect("create storage dir");
    rust_lib_zephyr_reader::api::data::init::init_storage(
        data_dir.to_string_lossy().to_string(),
    )
    .await
    .expect("init storage");

    // parse_book should work — it only reads metadata, not spine content
    rust_lib_zephyr_reader::api::core::parse_book(oversized_path.clone())
        .await
        .expect("parse_book should succeed even with oversized spine");

    // create_pagination_session should fail with ChapterTooLarge
    let config = test_typeset_config();
    let result = create_pagination_session(oversized_path, 0, config, None).await;

    assert!(
        result.as_ref().is_err_and(|e| matches!(e, AppError::ChapterTooLarge { .. })),
        "expected ChapterTooLarge error, got: {:?}",
        result.as_ref().err(),
    );
}
