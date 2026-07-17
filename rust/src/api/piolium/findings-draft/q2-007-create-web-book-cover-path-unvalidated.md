---
id: q2-007
phase: Q2
slug: create-web-book-cover-path-stored-unvalidated
severity: low
---

# create_web_book Stores User-Controlled cover_path Without Validation

## Location

- `src/api/book.rs` (lines 127-144) — `create_web_book`
- `src/domain/book/service.rs` (lines 105-117) — `create_web_book`

## Description

The `create_web_book` function accepts a `cover_path: Option<String>` parameter and stores it directly in the database without validation or sanitization:

```rust
pub async fn create_web_book(
    title: String,
    author: String,
    file_path: String,
    chapter_count: i32,
    total_characters: i64,
    cover_path: Option<String>,              // ❌ unvalidated
    description: Option<String>,
) -> Result<Book, AppError> {
    let book = Book::new(
        file_path.to_string(), 0, title.to_string(), BookFormat::Txt, chapter_count, total_characters,
        None, None, Some(author.to_string()),
        cover_path.map(|s| s.to_string()),    // ❌ stored as-is
        // ...
    );
```

While this is low severity in isolation, it becomes a **force multiplier** for finding q2-002 (`delete_book` cover path traversal). The stored `cover_path` is later retrieved and used in file deletion operations without further validation:

```rust
// In delete_book:
let full_path = std::path::Path::new(covers_dir).join(&cover_path);
```

## Impact

An attacker who can call `create_web_book` can plant a path traversal payload (e.g., `../../tmp/malicious`) in the database. When `delete_book` is later called for that book, the stored path is joined with `covers_dir` to construct a file deletion target.

## Attacker Control

All parameters are provided by the Flutter caller.

## Runtime

Local application process.

## Trust Boundary

User-supplied data stored to the database without sanitization.

## Reachability

**reachable** — `create_web_book` is a public `#[frb]` function.

## Recommendation

- Strip directory components from `cover_path` before storing: `Path::new(cover_path).file_name()`
- Apply the same sanitization used in `EpubCoverExtractor` (alphanumeric + `-` + `_`)
- Verify the stored path doesn't contain path separators
