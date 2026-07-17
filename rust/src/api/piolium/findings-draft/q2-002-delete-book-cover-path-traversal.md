---
id: q2-002
phase: Q2
slug: delete-book-cover-path-traversal
severity: medium
---

# Arbitrary File Deletion via Cover Path in delete_book

## Location

- `src/api/book.rs` (lines 68-81) — `delete_book`
- `src/domain/book/service.rs` (lines 72-83) — `delete_book`

## Description

The `delete_book(book_id, covers_dir)` API function constructs a file deletion path by joining the `covers_dir` parameter (supplied by the Flutter caller) with the `cover_path` stored in the database. Neither the `covers_dir` parameter nor the `cover_path` value is validated for path traversal:

```rust
// service.rs
pub async fn delete_book(book_id: &str, covers_dir: &str) -> Result<(), AppError> {
    // ...
    if let Ok(Some(cover_path)) = BookRepository::find_cover_path(&pool, book_id).await {
        let full_path = std::path::Path::new(covers_dir).join(&cover_path);
        if full_path.exists()
            && let Err(e) = tokio::fs::remove_file(&full_path).await {
                tracing::warn!("[book] failed to delete cover file: {}", e);
            }
    }
    // ...
}
```

Additionally, the `create_web_book` API stores the `cover_path` from the caller directly in the database without validation, providing a persistence vector for path traversal payloads:

```rust
// service.rs
pub async fn create_web_book(
    // ...
    cover_path: Option<&str>,     // ❌ stored directly without validation
    // ...
) -> Result<Book, AppError> {
```

## Impact

An attacker who controls the Flutter/Dart side can delete arbitrary files the process has permission to delete by:
1. Calling `create_web_book` with a `cover_path` like `../../../important/config.db` to store a malicious path
2. Calling `delete_book` with a `covers_dir` that completes the traversal to a sensitive file

## Attacker Control

Both `covers_dir` and the stored `cover_path` are ultimately controlled by the Flutter side.

## Runtime

Local application process with user privileges.

## Trust Boundary

The `covers_dir` and `cover_path` parameters cross from the Flutter layer to the Rust domain layer without sanitization.

## Reachability

**reachable** — Both `delete_book` and `create_web_book` are public `#[frb]` functions.

## Recommendation

- Canonicalize `covers_dir` and verify it equals the expected covers directory
- Validate `cover_path` in `create_web_book` — it should be a single filename component, not a path
- Use `Path::file_name()` on stored cover_path before joining to strip directory components
