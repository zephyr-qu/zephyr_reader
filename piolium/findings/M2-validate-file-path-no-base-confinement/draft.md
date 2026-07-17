---
id: M2
phase: Q2
slug: validate-file-path-no-base-confinement
severity: medium
original_id: q2-002
PoC-Status: executed
Protocol: local
Auth-Required: no
Auth-Roles-Required: anonymous
---

# validate_file_path Lacks Directory-Base Confinement

## Summary

The Rust `validate_file_path` function in `common/security.rs` checks that a path exists and is a file, and returns its canonicalized form. It does **not** verify that the canonical path *stays within* an expected base directory (e.g. the app's data directory, or the user's chosen import directory). Every critical file-read API in `src/api/` delegates to this function before operating on the path.

## Affected Files

- `rust/src/common/security.rs` — `validate_file_path()` (lines 18–36)
- `rust/src/api/book.rs` — `get_epub_metadata`, `get_processed_epub_image_bytes`, `get_processed_epub_image` (lines 215–241)
- `rust/src/domain/book/service.rs` — `import_book()` (line 177)
- `rust/src/domain/cover/service.rs` — `extract_book_cover()` (line 16)
- `rust/src/domain/backup/service.rs` — `export_database`, `inspect_backup`, `restore_database` (lines 146–198)
- `rust/src/pipeline/chapter_ir.rs` — chapter IR building (line 227)

## Root Cause

```rust
pub fn validate_file_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() { return Err(...); }
    if !path.is_file()  { return Err(...); }
    let canonical = path.canonicalize()?;
    Ok(canonical.to_string_lossy().to_string())
}
```

The function ensures the file exists and produces a canonical path, but never checks `canonical.starts_with(allowed_base)`. An attacker (or a confused user) who can supply a `file_path` argument can point it at **any** file visible to the process, not just files in the app's document directory.

The Rust API surface that accepts raw file paths includes:

| API | Operation |
|-----|-----------|
| `get_epub_metadata` | Opens and parses EPUB metadata |
| `get_processed_epub_image_bytes` | Reads + decodes EPUB image |
| `get_processed_epub_image` | Reads + decodes + caches EPUB image |
| `import_book` | Validates → parses → stores book |
| `export_database` | Copies reader.db to destination |
| `restore_database` | Copies backup to reader.db |
| `initDictionary` (mdxPath) | Opens MDict at path |

## Attacker Control

On a **desktop** build or any platform where the process has broader filesystem access, a user-provided path (from file picker, CLI arguments, or another attack vector) could reference system files. On **mobile**, the OS sandbox mitigates this (each app has its own container), so the blast radius is limited to the app's own sandbox.

## Impact

- **Desktop only**: Arbitrary file read within process permissions using the EPUB parser as an oracle.
- **All platforms (confusion vector)**: A user who selects a file through the picker could accidentally trigger the parser on a non-book file. The `import_book` function would attempt to parse it, potentially causing a crash or wasted I/O.
- **`export_database` and `restore_database`**: Write operations that accept a `dest_path` / `backup_path` without scope enforcement. `restore_database` validates the path exists and contains a valid backup, then **overwrites** the live database — this is particularly dangerous.

## Evidence

`restore_database()` in `backup/service.rs`:

```rust
pub async fn restore_database(backup_path: String) -> Result<BackupManifest, AppError> {
    let validated = validate_file_path(&backup_path)?;  // exists && is file — no scope check
    let storage = ensure_storage()?;
    // ...
    storage.restore_from_backup(&validated).await?;    // overwrites reader.db
}
```

## PoC

5 Rust integration tests in `rust/tests/poc_path_escape.rs` demonstrate the vulnerability:

| Test | Evidence |
|------|----------|
| `test_poc_escape_basic` | Files outside sandbox directory accepted by `validate_file_path` |
| `test_poc_path_traversal` | Windows system file `C:\Windows\win.ini` accepted; relative paths resolved |
| `test_poc_cover_extraction_chain_exploitable` | External epub path accepted by cover chain |
| `test_poc_restore_database_scope_escape` | Malicious backup database accepted outside sandbox |
| `test_poc_whitelist_violation` | Files from any directory accepted despite intended app_data restriction |

## Recommendation

Add a base-directory check to `validate_file_path` (or provide a scoped variant):

```rust
pub fn validate_file_path_in(
    path_str: &str,
    allowed_base: &Path,
) -> Result<String, AppError> {
    let path = Path::new(path_str);
    if !path.exists() { return Err(...); }
    if !path.is_file()  { return Err(...); }
    let canonical = path.canonicalize()?;
    if !canonical.starts_with(allowed_base) {
        return Err(AppError::SecurityError {
            reason: "path escapes allowed directory".into(),
            path: path_str.into(),
        });
    }
    Ok(canonical.to_string_lossy().to_string())
}
```

Then at each call site, pass the app's data directory or `std::env::current_dir()` as `allowed_base` depending on context.
