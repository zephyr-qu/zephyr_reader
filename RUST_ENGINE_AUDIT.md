# Rust Engine Final Audit

> **Date**: 2026-06-03
> **Scope**: `rust/src/` (all non-generated .rs files), `rust/tests/`, `rust/benches/`, `rust/Cargo.toml`
> **Auditor**: Automated static analysis

---

## Executive Summary

The Rust engine codebase is well-structured overall — unsafe code is confined to generated FFI glue, error handling is thorough, and the async architecture is sound. However, **11 modules have entire test blocks commented out** (~740+ lines, ~50+ tests), leaving core storage repos and API surfaces with zero unit test coverage. Two critical performance issues were found in the vocabulary marker and bilingual API hot paths. The remaining findings are moderate-to-low severity.

| Severity | Count | Key areas |
|----------|-------|-----------|
| CRITICAL | 2 | Commented-out tests, regex recompilation |
| HIGH     | 2 | Mutex choice, canonicalize I/O |
| MEDIUM   | 5 | Singleton patterns, dead code |
| LOW      | 3 | Thin wrappers, module conventions |

---

## Findings

### CRITICAL

#### C1. Commented-out test blocks across 11 modules (~740 lines)

`#[cfg(test)] mod tests` blocks are commented out in every storage repository except `vocab_repo` and `dictionary_repo` (which have no tests at all — neither active nor commented). These were disabled during a refactor and never restored.

**Affected modules:**

| File | Lines | Tests |
|------|-------|-------|
| `rust/src/storage/repos/book_repo.rs` | 338-424 | 6 |
| `rust/src/storage/repos/bookmark_repo.rs` | 104-166 | 5 |
| `rust/src/storage/repos/category_repo.rs` | 143-201 | 6 |
| `rust/src/storage/repos/chapter_repo.rs` | 84-132 | 4 |
| `rust/src/storage/repos/layout_cache_repo.rs` | 30-71 | 1 |
| `rust/src/storage/repos/note_repo.rs` | 243-339 | 7 |
| `rust/src/storage/repos/progress_repo.rs` | 92-140+ | 4 |
| `rust/src/storage/repos/session_repo.rs` | 101-175+ | 5 |
| `rust/src/storage/repos/stats_repo.rs` | 225-299+ | 4 |
| `rust/src/api/bilingual.rs` | 283-371 | 8 |
| `rust/src/api/data/vocabulary.rs` | 118-183+ | 4 |

**Impact**: Zero test coverage for all CRUD operations in the storage layer. The integration tests in `rust/tests/` compensate partially (storage_test.rs, search_test.rs), but they test at the API level and are slower to run, harder to debug, and cover fewer edge cases. Unit-level corrections (null handling, constraint violations, upsert semantics) are untested.

**Recommendation**: Restore and fix up the commented tests. The test helpers and fixtures already exist in `test_utils.rs`. Expect ~2 hours of work to uncomment, fix import paths, and verify they pass.

**Files with no test module at all** (neither active nor commented):
- `rust/src/storage/repos/vocab_repo.rs`
- `rust/src/storage/repos/dictionary_repo.rs`

---

#### C2. `Regex::new()` recompiled on every `scan_for_vocabulary()` call

**File**: `rust/src/vocab_marker/mod.rs:18`

```rust
pub fn scan_for_vocabulary(text: &str) -> Vec<VocabularyMatch> {
    let re = Regex::new(r"[a-zA-Z]+(?:'[a-zA-Z]+)?").expect("static regex is valid");
    //   ^^^^^^^^^^ constructs + compiles the DFA on every call
```

Every invocation allocates, compiles the regex DFA, and deallocates. When scanning long chapters during reading, this is invoked per-chapter or per-paragraph — measurable overhead.

**Detection**: Direct read of the source file confirms this is not a `LazyLock` or `static` — the `Regex` is a local variable.

**Contrast**: The codebase already demonstrates the correct pattern 4 times in `rust/src/text/constants.rs`:
```rust
pub static TAG_PATTERN: LazyLock<Regex> = LazyLock::new(|| { ... });
```

**Impact**: Each `scan_for_vocabulary` call incurs ~10-100µs of regex compilation overhead (depending on pattern complexity). On a chapter with 500 paragraphs, this adds 5-50ms of unnecessary work.

**Recommendation**: Promote to `static VOCAB_PATTERN: LazyLock<Regex>`. 5-minute fix.

---

### HIGH

#### H1. `std::sync::Mutex` for SQLite connection pool

**File**: `rust/src/storage/db.rs:16`

```rust
pub struct StorageManager {
    pool: Mutex<Option<SqlitePool>>,
    //     ^^^^^^^^^^^^ std::sync::Mutex
```

In a tokio async context, `std::sync::Mutex` will block the worker thread if held across an `.await`. Currently lock durations are brief (get/set only, not held across `.await`), so it does not deadlock in practice. However, `parking_lot::Mutex` (already a dependency — used in `api/core.rs` for `PROVIDER_CACHE`) is a drop-in replacement that is faster and panics less on contention.

**Impact**: Low in practice today. Fragile — any future refactor that accidentally holds this lock across an `.await` will block the tokio worker, potentially starving other tasks.

**Recommendation**: Change to `parking_lot::Mutex` for consistency with the rest of the codebase. The `parking_lot` crate is already listed in `Cargo.toml:63`.

---

#### H2. `canonicalize()` called on every API entry

**File**: `rust/src/utils/security.rs:12-14`

```rust
let canonical = path
    .canonicalize()
    .map_err(|e| AppError::file_read_error(path_str, e.to_string()))?;
```

This function (`validate_file_path`) is called at the start of every major API call (parse, metadata, cover extraction, chapter reading) via `validate_file_path_async`. `canonicalize()` resolves symlinks and `..` components, which requires filesystem I/O.

**Impact**: Correct and necessary for security (path traversal prevention). Each call adds ~0.1-1ms of syscall latency (single I/O, usually cached by VFS). Not a hot-path bottleneck, but the `to_string_lossy().to_string()` allocates for every call too. Acceptable as-is — caching the validated path would introduce complexity for marginal gain.

**Recommendation**: Leave as-is. Once-per-request I/O is acceptable.

---

### MEDIUM

#### M1. Five global singleton `OnceLock`/`LazyLock` instances

Each module independently manages its own singleton:

| Variable | File | Type |
|----------|------|------|
| `STORAGE` | `rust/src/storage/mod.rs:26` | `OnceLock<StorageManager>` |
| `SEARCH_ENGINE` | `rust/src/api/search.rs:11` | `OnceLock<SearchEngine>` |
| `COVER_REGISTRY` | `rust/src/parser/cover_extractor.rs:276` | `OnceLock<ThreadSafeCoverRegistry>` |
| `JIEBA` | `rust/src/search/engine.rs:10` | `OnceLock<Jieba>` |
| `MDICT` | `rust/src/api/dictionary.rs:71` | `LazyLock<Mutex<Option<MdictEngine>>>` |
| `PROVIDER_CACHE` | `rust/src/api/core.rs:50` | `LazyLock<Mutex<LruCache<...>>>` |

**Impact**: Initialization order is implicit but `init.rs` orchestrates the critical ones explicitly. This is a well-known pattern for app-level singletons and is acceptable for this codebase. No data races observed.

**Observation**: `MDICT` uses `LazyLock` (not `OnceLock`) and wraps an `Option<MdictEngine>` in a `Mutex` to allow close/reinit. The `close_dictionary()` function replaces the inner value. This is a reasonable design for a resource that may be hot-swapped.

**Recommendation**: No action needed. If the codebase grows to need dependency injection, centralize in `init.rs`.

---

#### M2. `#[allow(dead_code)]` on `KvStore::db`

**File**: `rust/src/storage/kv_store.rs:15-17`

```rust
pub struct KvStore {
    #[allow(dead_code)]
    db: sled::Db,
    layout_cache: sled::Tree,
}
```

The `db` field (the raw `sled::Db`) is held only to keep the database alive. Opening a `Tree` does not keep the `Db` alive in sled — if the `Db` is dropped, the `Tree` becomes invalid. The `#[allow(dead_code)]` is intentional and correct. The field is indirectly accessed through `layout_cache`.

**Recommendation**: Add a documentation comment explaining why `db` is retained (keeps the sled database open). Remove `#[allow(dead_code)]` if the field has at least one reader somewhere (checking references), otherwise keep it with explanation.

---

#### M3. Commented-out code in `bilingual.rs` API

**File**: `rust/src/api/bilingual.rs:283-371`

90 lines of commented test code including `use` imports and 8 test functions. This is the same issue as C1 but the API layer, not the storage layer.

**Impact**: Duplicates C1. Kept as a separate finding because it's API-level tests for a complex function (`align_bilingual_content`, `create_bilingual_highlight_pair`, etc.) that would be harder to cover from integration tests alone.

**Recommendation**: Same as C1 — restore or delete.

---

#### M4. `common/mod.rs` has commented-out helper code

**File**: `rust/tests/common/mod.rs:22-28`

```rust
// pub async fn ensure_storage(dir: &TempDir) -> String {
//     ...
// }
```

Minor — a commented-out utility function. The three integration test files (storage_test, search_test, api_test) each replicate their own `ensure_storage_initialized()` rather than sharing one via `common`.

**Recommendation**: Either delete the commented block or consolidate the duplicated `ensure_storage_initialized` functions into `common/mod.rs`.

---

#### M5. `vocab_repo.rs` and `dictionary_repo.rs` lack any test module

Unlike the 11 modules that have commented-out tests, these two have **no test module at all** — not even commented.

**Files**:
- `rust/src/storage/repos/vocab_repo.rs` (4.9KB, 150 lines) — SQL CRUD operations for vocabulary words
- `rust/src/storage/repos/dictionary_repo.rs` (2.0KB, 60 lines) — SQL CRUD for dictionary metadata

**Impact**: Both modules are small and straightforward (thin SQL wrappers), so risk is low. Still, zero coverage.

**Recommendation**: Add basic unit tests when the nearby commented tests are restored.

---

### LOW

#### L1. Thin module wrappers (minimal code)

Several modules exist only as re-export points:

| File | Size | Content |
|------|------|---------|
| `rust/src/search/mod.rs` | 148 bytes | `mod engine; pub use engine::*;` |
| `rust/src/domain/mod.rs` | 149 bytes | `mod error; pub mod types; pub use error::AppError;` |
| `rust/src/storage/models/mod.rs` | inferred tiny | re-exports |

This is a standard Rust convention and is not a code smell. Acceptable.

#### L2. `Parser` enum with `Clone, Copy` — zero-sized unit variants

**File**: `rust/src/parser/mod.rs:23-29`

```rust
#[derive(Clone, Copy)]
pub enum Parser {
    Txt(TxtParser), Epub(EpubParser), Pdf(PdfParser), Md(MdParser),
}
```

All inner types are zero-sized unit structs, so `Copy` is valid. The dispatch is clean and idiomatic. No issue.

#### L3. API functions take `String` instead of `&str`

All FRB-exported functions take `String` parameters. This is required by the FFI boundary — `flutter_rust_bridge` does not support `&str` in exported functions. The internal implementations accept `&str/&Path` where possible.

**Example**: `rust/src/api/core.rs` `parse_book(file_path: String)` → calls `validate_file_path_async(&file_path)` which takes `&str`. The internal code re-borrows from the owned String.

**Impact**: The FFI caller already owns the String, so no extra allocation at the callsite. Internal functions that accept `&str` avoid copying. This pattern is correct and consistent.

---

### POSITIVES

- **No unsafe Rust** outside `frb_generated.rs` (auto-generated, not in audit scope). The entire engine is safe Rust.

- **`AppError` is well-designed**: a `thiserror` enum with semantic variants, `From` impls for `anyhow::Error` and `sqlx::Error`, and FRB-visible non-opaque tagging. FFI surface returns `Result<T, AppError>` consistently — no panics cross the boundary.

- **Async architecture is sound**: `tokio::spawn_blocking` for filesystem I/O, CPU-heavy work, and `canonicalize()`. No blocking calls on the tokio worker thread.

- **`memmap2`** used for large file reads via `read_text_mmap` — efficient for large TXT/MD files.

- **`bincode` + `xxh3`** for layout cache serialization — zero-copy where possible, fast hashing for cache keys.

- **`parking_lot::Mutex`** used for `PROVIDER_CACHE` LRU cache — correct choice for hot path.

- **`LazyLock`** for all shared regex patterns in `constants.rs` (4 patterns) — correct and efficient.

- **`OnceLock` for Jieba** tokenizer — lazy initialization, never recreated.

- **`#[cfg(test)]` utilities** in `test_utils.rs` provide `setup_test_db()`, `test_book()`, `test_highlight()`, `test_annotation()`, `test_bookmark()`, `test_category()`, `test_chapter()`, `test_progress()`, `test_session()` — a comprehensive set of factory functions.

- **Integration tests** in `rust/tests/` are active and thorough:
  - `storage_test.rs` (666 lines, API-level storage CRUD)
  - `search_test.rs` (531 lines, FTS5 search + Chinese tokenization)
  - `api_test.rs` (API flow tests)
  - `bilingual_test.rs` (alignment algorithm tests)
  - `typeset_test.rs` (typesetting tests)
  - `file_io_test.rs` (trivial file helpers)

- **Benchmarks** in `rust/benches/parsing_benchmark.rs` use criterion with proper setup, throughput measurement, and HTML reports.

- **`#[cfg(test)]` annotations** on `truncate_snippet()` in `search/engine.rs` — only compiled under test.

---

## Recommendations (ordered by impact/effort)

| # | Action | Impact | Effort |
|---|--------|--------|--------|
| 1 | Promote `scan_for_vocabulary` regex to `static LazyLock<Regex>` | Fixes per-call recompilation | 5 min |
| 2 | Restore 11 commented-out test blocks | Restores ~50+ unit tests | ~2 hr |
| 3 | Add doc comment to `KvStore::db` field explaining lifetime | Removes dead-code confusion | 2 min |
| 4 | Switch `StorageManager::pool` to `parking_lot::Mutex` | Consistency, prevents future block | 5 min |
| 5 | Delete or consolidate commented `ensure_storage` in `tests/common/mod.rs` | Housekeeping | 2 min |
| 6 | Add basic tests for `vocab_repo` and `dictionary_repo` | Closes coverage gap | 20 min |
| 7 | Cull commented-out test blocks if restoration is not planned | Removes ~740 dead lines | 10 min |

**Immediate action items** (recommended before next CI run):
- Items 1, 2, 4 are the highest-value: fix the regex, restore the tests, and harden the mutex. Total effort ~2.5 hours.

---

## File Manifest

Inspected files (40+ modules):

- `rust/Cargo.toml` — dependencies, edition 2024, features
- `rust/src/lib.rs` — module tree (14 modules)
- `rust/src/init.rs` — initialization orchestration
- `rust/src/domain/{mod,error,types}.rs` — error types, domain models
- `rust/src/api/{mod,core,bilingual,search,dictionary,typeset,cover,epub,md,backup,vocab_marker}/` — FFI API layer
- `rust/src/api/data/{mod,init,book,note,chapter,progress,bookmark,category,session,stats,vocabulary}/` — data API
- `rust/src/storage/{mod,db,kv_store}/` — storage layer
- `rust/src/storage/models/` — storage models (metadata, typeset, rich_text, pagination)
- `rust/src/storage/repos/` — 13 repository files (all CRUD operations)
- `rust/src/search/{mod,engine}/` — FTS5 search + jieba
- `rust/src/text/{mod,constants,typeset,pagination,line_break,chapter_detect,bilingual,char_width,css,rich_text}/` — text processing
- `rust/src/parser/{mod,book_parser,cover_extractor,registry,provider}/` — parsing dispatch
- `rust/src/parser/{epub,txt,pdf,md}/` — format parsers
- `rust/src/dictionary/{mod,mdict_engine,models}/` — dictionary engine
- `rust/src/utils/security.rs` — path validation
- `rust/src/vocab_marker/{mod,wordlists}/` — vocabulary word scanning
- `rust/tests/` — 6 integration test files + common
- `rust/benches/parsing_benchmark.rs` — criterion benchmarks
