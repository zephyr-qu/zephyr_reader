---
id: q2-001
phase: Q2
slug: cover-extraction-output-dir-path-traversal
severity: medium
---

# Arbitrary File Write via Cover Extraction Output Directory

## Location

- `src/api/cover.rs` (lines 7-26) — `extract_book_cover`, `extract_and_save_cover`
- `src/domain/cover/service.rs` (lines 14-18) — `extract_book_cover`
- `src/domain/cover/engine.rs` (lines 80-119) — `EpubCoverExtractor::extract_cover`

## Description

The `extract_book_cover(file_path, output_dir)` and `extract_and_save_cover(book_id, file_path, output_dir)` API functions accept an `output_dir` parameter from the caller (Flutter/Dart side) **without any path validation or sanitization**. The `file_path` input is validated through `validate_file_path()` for existence, but `output_dir` is used directly in filesystem operations:

```rust
// service.rs — validates file_path but NOT output_dir
pub async fn extract_book_cover(file_path: &str, output_dir: &str) -> Result<String, AppError> {
    let validated_path = validate_file_path(file_path)?;     // ✅ validated
    let registry = get_cover_registry();
    registry.extract_cover(&validated_path, output_dir)       // ❌ output_dir unvalidated
}
```

Inside `EpubCoverExtractor::extract_cover`:
```rust
std::fs::create_dir_all(output_dir)?;                        // ❌ creates directory at attacker-controlled path
let output_path = Path::new(output_dir)
    .join(format!("{}.{}", safe_file_stem, extension));
std::fs::write(&output_path, cover_data)?;                   // ❌ writes file at attacker-controlled path
```

While the filename stem is sanitized (alphanumeric + `-` + `_`), the directory path is not, allowing path traversal via `output_dir` values like `../../tmp/`.

## Impact

An attacker who controls the Flutter/Dart caller can write arbitrary image data (the book's cover image) to any directory the application process can write to. While the written content is limited to the extracted cover image, the attacker controls both the destination directory and the file extension (jpg/png/gif/webp/bmp).

## Attacker Control

The input is controlled by the Flutter application layer (potentially influenced by user action in the GUI or file selection dialog).

## Runtime

Local application process running with the user's privileges.

## Trust Boundary

The `output_dir` parameter crosses from the Flutter (untrusted from Rust's perspective) to the Rust domain layer without sanitization.

## Reachability

**reachable** — `extract_book_cover` is a public `#[frb]` function callable from Flutter.

## Recommendation

- Apply `validate_file_path()` or a new directory validation function to `output_dir`
- Restrict output directory to an allowlist (e.g., app data directory or a subdirectory thereof)
- Canonicalize the path and verify it's within the expected base directory before writing
