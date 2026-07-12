// Shared test utilities — not every test binary uses every function.
#![allow(dead_code)]

use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use tempfile::TempDir;
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

use rust_lib_zephyr_reader::api::data::init::init_storage;
use rust_lib_zephyr_reader::domain::{LanguageType, PageDescriptor, TypesetConfig};

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/// Fixed `TypesetConfig` matching the strategy used by Dart
/// `core_pagination_test.dart`.  A fixed small viewport avoids page-boundary
/// drift that can happen with `Default`.
pub fn test_typeset_config() -> TypesetConfig {
    TypesetConfig {
        page_width: 800,
        page_height: 600,
        font_size: 16,
        line_spacing: 1.5,
        language: LanguageType::Mixed,
        ..Default::default()
    }
    .validate_and_fix()
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

/// Copy an EPUB fixture to a temporary directory, initialise storage, `parse_book`.
///
/// Returns `(TempDir, file_path, book_id)`.  Each test gets its own `TempDir`
/// so SQLite state never leaks between tests.
pub async fn setup_parsed_epub(fixture_path: &Path) -> (TempDir, String, String) {
    let temp_dir = TempDir::new().expect("failed to create temp dir");
    let data_dir = temp_dir.path().to_str().unwrap().to_string();

    if let Err(e) = init_storage(data_dir).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {e}");
        }
    }

    // Copy fixture to temp with a unique name so `parse_book` can write a new
    // DB row without conflicting with other copies of the same filename.
    let file_name = fixture_path.file_name().unwrap().to_str().unwrap();
    let dest = temp_dir.path().join(format!("test_{}", file_name));
    std::fs::copy(fixture_path, &dest).expect("failed to copy fixture");
    let file_path = dest.to_string_lossy().to_string();

    let book_id = rust_lib_zephyr_reader::api::core::parse_book(file_path.clone())
        .await
        .expect("parse_book should succeed");

    (temp_dir, file_path, book_id)
}

/// Build an EPUB with an image in the first spine chapter from `medium.epub`.
/// Returns `None` when the fixture is missing.
pub fn build_image_epub_from_medium(out_dir: &Path) -> Option<PathBuf> {
    let src_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../test/fixtures/medium.epub");
    if !src_path.exists() {
        return None;
    }

    let src_bytes = std::fs::read(&src_path).ok()?;
    let src_zip = std::io::Cursor::new(src_bytes);
    let mut src_archive = zip::ZipArchive::new(src_zip).ok()?;

    let out_path = out_dir.join("with_image.epub");
    let out_file = std::fs::File::create(&out_path).ok()?;
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
        let mut entry = src_archive.by_name(name).ok()?;
        let opts = if name == "mimetype" {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Stored)
                .unix_permissions(0o644)
        } else {
            SimpleFileOptions::default()
                .compression_method(zip::CompressionMethod::Deflated)
                .unix_permissions(0o644)
        };

        let is_chapter_spine = name.starts_with("OEBPS/chapter") && name.ends_with(".xhtml");

        if is_chapter_spine {
            out_zip.start_file(name, opts).ok()?;
            out_zip.write_all(image_html.as_bytes()).ok()?;
        } else {
            let mut buf = Vec::new();
            entry.read_to_end(&mut buf).ok()?;
            out_zip.start_file(name, opts).ok()?;
            out_zip.write_all(&buf).ok()?;
        }
    }
    out_zip.finish().ok()?;
    Some(out_path)
}

/// Initialise storage, parse an image EPUB built from `medium.epub`.
pub async fn setup_parsed_image_epub() -> Option<(TempDir, String)> {
    let temp_dir = TempDir::new().ok()?;
    let out_path = build_image_epub_from_medium(temp_dir.path())?;
    let file_path = out_path.to_string_lossy().to_string();

    let data_dir = temp_dir.path().join("storage");
    std::fs::create_dir_all(&data_dir).ok()?;
    if let Err(e) = init_storage(data_dir.to_string_lossy().to_string()).await {
        if !e.to_string().contains("already initialized") {
            panic!("failed to init storage: {e}");
        }
    }

    rust_lib_zephyr_reader::api::core::parse_book(file_path.clone())
        .await
        .expect("parse_book should succeed");

    Some((temp_dir, file_path))
}

// ---------------------------------------------------------------------------
// Shared assertions  (P0 regression checks)
// ---------------------------------------------------------------------------

/// Every page's `start_offset ≤ end_offset` and offsets are non-decreasing.
pub fn assert_monotonic_descriptors(descriptors: &[PageDescriptor]) {
    for (i, desc) in descriptors.iter().enumerate() {
        assert!(
            desc.start_offset <= desc.end_offset,
            "page {}: start_offset {} > end_offset {}",
            i,
            desc.start_offset,
            desc.end_offset,
        );
        if i > 0 {
            assert!(
                desc.start_offset >= descriptors[i - 1].end_offset,
                "page {} start_offset {} < previous end_offset {}",
                i,
                desc.start_offset,
                descriptors[i - 1].end_offset,
            );
        }
    }
}

/// Adjacent pages must not duplicate content: `page[N+1]` must NOT start with
/// the full text of `page[N]`.
