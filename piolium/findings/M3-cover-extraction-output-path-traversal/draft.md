---
id: M3
phase: Q2
slug: cover-extraction-output-path-traversal
severity: medium
original_id: q2-003
PoC-Status: executed
Protocol: local
Auth-Required: no
Auth-Roles-Required: anonymous
---

# Cover Extraction Accepts Unvalidated output_dir

## Summary

`extract_book_cover` in `rust/src/domain/cover/engine.rs` accepts an `output_dir` parameter and writes the extracted cover image to `${output_dir}/{safe_file_stem}.{ext}` without verifying the target directory is within the app's storage.

## Affected Files

- `rust/src/domain/cover/engine.rs` — `EpubCoverExtractor::extract_cover()` (lines 69–117)
- `rust/src/domain/cover/service.rs` — `extract_book_cover()` (line 17) and `extract_and_save_cover()`
- `rust/src/api/cover.rs` (entry point exposed to Dart)

## Root Cause

The `extract_cover` method constructs the output path as:

```rust
fn extract_cover(&self, file_path: &str, output_dir: &str) -> Result<String, AppError> {
    // ...
    let output_path = Path::new(output_dir)
        .join(format!("{}.{}", safe_file_stem, extension))
        .to_string_lossy()
        .to_string();

    std::fs::create_dir_all(output_dir)?;
    std::fs::write(&output_path, cover_data)?;
    Ok(output_path)
}
```

While `safe_file_stem` is sanitized (only alphanumeric, `-`, `_`), the `output_dir` is **not** validated at all. The function creates the directory if it does not exist and writes a file into it.

The call chain from Dart is:
`library method (Dart)` → `api/cover.rs` → `cover/service.rs::extract_book_cover(file_path, output_dir)` → `engine.rs::extract_cover(file_path, output_dir)`

## Attacker Control

The `output_dir` ultimately originates from the Dart caller. If any Dart code path passes a user-controlled directory (e.g. from app settings like `dictMdxPath`, temp directory resolution, or file-picker output), the cover engine would write files there. The attacker does not control the file *name* (it's `{sanitized_stem}.jpg/png`) but controls the **directory**.

## Impact

- **Desktop**: An attacker could write a JPEG file to an arbitrary directory writable by the process, potentially overwriting existing files if the sanitized filename collides.
- **Mobile**: OS sandboxing limits the write to the app container, but the attacker could fill storage or write outside the intended cache directory.
- **Combined with other bugs**: If the `output_dir` is set to a location that gets exported (e.g. the backup directory, or the WebDAV sync directory), the cover file leaks to an external service.

## PoC

A Rust integration test (`poc.rs`) demonstrates the vulnerability by:

1. Creating an `app_covers` directory (the intended storage area) and a separate `attacker_controlled` directory
2. Building a minimal valid EPUB file with an embedded JPEG cover image
3. Calling `extract_book_cover` with `output_dir` set to the attacker-controlled path
4. Verifying the cover file (`poc_book.jpg`, 107 bytes) is written to the attacker-chosen directory instead of `app_covers`

### Run

```bash
cd piolium/findings/M3-cover-extraction-output-path-traversal
bash poc.sh
```

### Evidence

```
Intended cover directory:  /tmp/.tmpXXX/app_covers
Attacker-controlled dir:   /tmp/.tmpXXX/attacker_controlled

File written inside intended dir? false
File written inside attacker dir?  true

STATUS: VULNERABILITY CONFIRMED — cover written to attacker-controlled path
```

Full output in `evidence/exploit.log`.

## Recommendation

Validate `output_dir` against an allowed base path before creating/writing:

```rust
let app_cover_dir = get_app_cover_dir();  // e.g. app_data/Reader/covers
if !Path::new(output_dir).canonicalize()?.starts_with(&app_cover_dir) {
    return Err(AppError::SecurityError {
        reason: "output_dir escapes cover directory".into(),
        path: output_dir.into(),
    });
}
```

Alternatively, remove the `output_dir` parameter from the public API and always write to the app-managed cover directory.
