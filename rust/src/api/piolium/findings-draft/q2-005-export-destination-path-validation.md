---
id: q2-005
phase: Q2
slug: export-database-requires-existing-destination
severity: low
---

# export_database Validates Destination Path for Existence (UX Design Issue)

## Location

- `src/domain/backup/service.rs` (lines 114-117) — `export_database`
- `src/common/security.rs` (lines 13-28) — `validate_file_path`

## Description

The `export_database(dest_path)` function calls `validate_file_path(&dest_path)` on the **output** destination path. The `validate_file_path` function requires the path to both exist and be a regular file. This means the database export function **cannot create a new file** — the destination must already exist before calling export:

```rust
pub async fn export_database(dest_path: String) -> Result<BackupManifest, AppError> {
    let validated = validate_file_path(&dest_path)?;  // ❌ requires dest to exist
    // ...
    std::fs::copy(&db_path, &dest)                     // overwrites existing file
```

This is inconsistent with user expectations for an "export" operation, which typically creates a new file at the specified path.

## Impact

- Users receive a confusing `FileNotFound` error when trying to export to a new file path
- Users must create an empty file first before exporting
- Not a direct security vulnerability, but a defense-in-depth concern: `validate_file_path` was designed for reading files, not writing them

## Attacker Control

The `dest_path` is controlled by the Flutter caller.

## Reachability

**reachable** — `export_database` is a public `#[frb]` function.

## Recommendation

Create a dedicated `validate_output_path` function that validates the parent directory exists and is writable, rather than requiring the output file to pre-exist:

```rust
pub fn validate_output_path(path_str: &str) -> Result<String, AppError> {
    let path = Path::new(path_str);
    let parent = path.parent().ok_or_else(|| AppError::InvalidInput {
        reason: "path has no parent directory".into(),
    })?;
    if !parent.exists() {
        return Err(AppError::FileNotFound { path: parent.to_string_lossy().into() });
    }
    Ok(path.to_string_lossy().to_string())
}
```
