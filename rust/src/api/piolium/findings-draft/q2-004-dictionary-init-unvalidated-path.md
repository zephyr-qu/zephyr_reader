---
id: q2-004
phase: Q2
slug: dictionary-engine-unvalidated-file-path
severity: low
---

# Unvalidated File Paths in Dictionary Engine Initialization

## Location

- `src/api/dictionary.rs` (lines 73-77) — `init_dictionary`
- `src/domain/dictionary/service.rs` (lines 24-35) — `init_dictionary`
- `src/domain/dictionary/engine.rs` (lines 20-25) — `Engine::open`

## Description

The `init_dictionary(mdx_path, mdd_path)` API function accepts an `mdx_path` parameter from the caller without any file path validation (no call to `validate_file_path`). The path is passed directly to `Mdx::new()` which memory-maps the file:

```rust
// service.rs
pub async fn init_dictionary(mdx_path: &str, mdd_path: Option<String>) -> Result<(), AppError> {
    let engine = Engine::open(mdx_path, mdd_path.as_deref())    // ❌ mdx_path unvalidated
```

```rust
// engine.rs
pub fn open(mdx_path: &str, mdd_path: Option<&str>) -> Result<Self, rust_mdict::MdictError> {
    let mdx = Mdx::new(mdx_path)?;           // ❌ mmap's any file path
```

This contrasts with the `import_book` and `extract_book_cover` functions which consistently call `validate_file_path()` before operating on user-supplied paths.

## Impact

An attacker who controls the Flutter side can cause the application to memory-map any file the user has read access to. Since `Mdx::new` expects a valid .mdx format, this will likely error out for non-.mdx files, but an attacker could:
- Trigger resource exhaustion on very large files via mmap
- Trigger a denial-of-service by providing a path to a slow device file

## Attacker Control

The `mdx_path` parameter is controlled by the Flutter application layer.

## Runtime

Local application process with user privileges.

## Trust Boundary

The `mdx_path` crosses from Flutter to Rust without validation.

## Reachability

**reachable** — `init_dictionary` is a public `#[frb]` function.

## Recommendation

Add `validate_file_path()` call before opening the .mdx file, consistent with other file processing functions:

```rust
pub async fn init_dictionary(mdx_path: &str, mdd_path: Option<String>) -> Result<(), AppError> {
    let validated_mdx = validate_file_path(mdx_path)?;
    // ...
    let engine = Engine::open(&validated_mdx, mdd_path.as_deref())?;
    // ...
}
```
