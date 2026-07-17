# [M3] Cover Extraction Accepts Unvalidated `output_dir` — Arbitrary Directory Write

## Summary

The `extract_book_cover` function in the cover-extraction engine accepts a caller-supplied `output_dir` parameter and writes the extracted cover image into `${output_dir}/{sanitized_stem}.{ext}` without verifying the target directory is within the application's allowed storage area. While the file *stem* is sanitized against path traversal (alphanumeric, `-`, `_` only), the `output_dir` itself is never validated. An attacker who controls or influences the `output_dir` value (e.g., through a Dart-side setting, file-picker output, or a chained vulnerability) can write JPEG/PNG files to any directory writable by the process.

## Details

The vulnerable code is in the `EpubCoverExtractor::extract_cover` implementation at [`rust/src/domain/cover/engine.rs` lines 67–120](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/cover/engine.rs#L67-L120).

```rust
fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String, AppError> {
    let mut epub_file = crate::parser::epub::archive_reader::EpubFile::open(file_path)?;
    let cover_data = epub_file.read_cover()
        .ok_or_else(|| AppError::Other("EPUB cover not found".into()))?;

    let file_stem = Path::new(file_path)
        .file_stem().and_then(|s| s.to_str()).unwrap_or("cover");

    // Only the file stem is sanitized — not the output_dir
    let safe_file_stem: String = file_stem.chars()
        .filter(|c| c.is_alphanumeric() || *c == '-' || *c == '_')
        .take(100)
        .collect();

    // ... extension detection ...

    // output_dir is used AS-IS — no validation, no canonicalization, no bounds check
    let output_path = Path::new(output_dir)
        .join(format!("{}.{}", safe_file_stem, extension))
        .to_string_lossy()
        .to_string();

    std::fs::create_dir_all(output_dir)?;       // creates arbitrary directory
    std::fs::write(&output_path, cover_data)?;   // writes file into it
    Ok(output_path)
}
```

The key observation: `safe_file_stem` eliminates `../` and other traversal sequences from the *filename*, but the `output_dir` parameter is concatenated directly onto the path without any check. Additionally, `std::fs::create_dir_all(output_dir)` will recursively create any directory tree supplied by the attacker.

The call chain is:

1. Dart calls [`api/cover.rs::extract_book_cover(file_path, output_dir)`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/api/cover.rs#L12-L15)
2. Which delegates to [`service.rs::extract_book_cover(file_path, output_dir)`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/cover/service.rs#L17-L22)
3. Which calls `validate_file_path(file_path)` (validates the *input* EPUB, not the output) and then [`registry.extract_cover(&validated_path, output_dir)`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/domain/cover/engine.rs#L67-L120) passing `output_dir` through unchanged.

The `validate_file_path` function in [`rust/src/common/security.rs`](https://github.com/2084035767/zephyr_reader/blob/23e2192cd8c9f64996dc344a8c2b7bb3067cddb6/rust/src/common/security.rs#L18-L33) only checks existence and canonicalizes the *input* path — it never inspects or constrains `output_dir`.

## Root Cause

The `extract_cover` method (and its callers) treat `output_dir` as a trusted parameter, placing all sanitization effort on the file stem alone. The `CoverExtractor` trait's `extract_cover` signature accepts a bare `&str` for the output directory, giving every consumer of this trait the opportunity to supply an arbitrary path. There is no canonicalization, no prefix check against an allowed base directory, and no authorization step before `create_dir_all` + `write`.

The design incorrectly assumes that the caller (Dart) will always supply a safe directory. If any Dart code path passes a user-controlled value (from app settings like `dictMdxPath`, file-picker output, or a sync-service configuration), the cover extraction becomes an arbitrary-write primitive.

## Proof of Concept (PoC)

The PoC is a Rust integration test available at [`poc.rs`](poc.rs) (wrapped by [`poc.sh`](poc.sh)). It:

1. Creates two temporary directories: `app_covers` (the intended storage area) and `attacker_controlled` (a completely separate location).
2. Builds a minimal valid EPUB containing a 107-byte JPEG cover image.
3. Calls `extract_book_cover` with `output_dir` set to the attacker-controlled directory.
4. Checks where the cover file `poc_book.jpg` was actually written.

### Reproduce

```bash
cd piolium/findings/M3-cover-extraction-output-path-traversal
bash poc.sh
```

### Evidence (from [`evidence/exploit.log`](evidence/exploit.log))

```
========== PoC: Cover Extraction Path Traversal ==========
Intended cover directory:  "C:\...\.tmpXXX\app_covers"
Attacker-controlled dir:   C:\...\.tmpXXX\attacker_controlled
Directories are different: true
EPUB size: 1614 bytes

--- Calling extract_book_cover(output_dir = attacker_dir) ---
Returned path: C:\...\.tmpXXX\attacker_controlled\poc_book.jpg

========== EVIDENCE ==========
File written inside intended dir? false
File written inside attacker dir?  true
STATUS: VULNERABILITY CONFIRMED — cover written to attacker-controlled path
```

The decisive JSON output confirms the effect:
```json
{"status":"confirmed","evidence":"cover file written to attacker-chosen directory at .../attacker_controlled/poc_book.jpg","notes":"output_dir parameter accepted arbitrary path without validation"}
```

The file name `poc_book.jpg` is sanitized (no traversal in the stem), but the directory portion of the path is fully attacker-chosen. The test proves the function will happily create and write into any directory.

## Impact

**Severity: Medium (CVSS 5.3 — CWE-22 Path Traversal: `..` equivalent but via directory parameter)**

- **Desktop environments**: An attacker who controls the `output_dir` parameter can write a JPEG cover image to any filesystem path writable by the application process. On Linux/macOS this includes `~/.ssh/`, `~/.config/`, and other sensitive user directories. The written file name is predictable (`{sanitized_stem}.{jpg|png|gif|webp|bmp}`), which limits but does not eliminate the risk of overwriting existing files (e.g., a collision with a critical configuration file name is unlikely but a large number of covers could fill storage or pollute directories).

- **Mobile (iOS/Android)**: OS-level sandboxing restricts writes to the app container, so arbitrary system directories are not reachable. However, the attacker could write outside the designated covers cache directory into other app-owned directories (e.g., the database directory, backup staging area, or WebDAV sync folder), causing the cover image to be leaked through backup or sync exports.

- **Combined with other bugs**: If paired with a vulnerability that allows controlling the `output_dir` Dart-side (e.g., an insecure app setting like `dictMdxPath`), this becomes a reliable arbitrary-file-write primitive. The file content itself is a valid JPEG/PNG — the attacker controls which image is in the EPUB — so it could also be used to plant decoy or misleading images in trusted locations.

**PoC Status**: `executed` — the real-environment test confirmed the cover file was written to the attacker-chosen path.
