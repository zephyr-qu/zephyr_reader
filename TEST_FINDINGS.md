# Integration Test Findings

## Summary

Integration tests for the Rust FFI pipeline were created, and chapter detection was improved.
- `test/features/reader/core_pagination_test.dart` — Parse → paginate → content pipeline (22 tests: 10 synthetic fixture + 4 活着.txt + 4 活着.epub + 4 mixed_content.md, all active)
- `test/features/reader/auto_spacing_test.dart` — CJK-Latin auto-spacing behavior (1 parse test active, 5 pagination tests scaffolded/skipped)
- `test/helpers/integration_test_helper.dart` — Storage init/teardown + file helpers
- `rust/src/text/constants.rs` — CHAPTER_PATTERN_ZH expanded: `序[言引]?`, `自序`, `代序`, `跋`, `附录`, `\S+版自序` 等无编号章节标题模式

## ~~Bug Found: `paginate_all_content` returns 0 pages~~ **FIXED**

### Symptom (was)

Both `paginateChapter()` and `paginateAllContent()` return **0 pages** despite:
- `parseBook()` succeeding with valid metadata and chapters
- Chapter bounds being valid (startIndex=0, endIndex > 0)
- The fixture file existing and being readable

All pagination pipeline integration tests were **skipped** with documented skip reason.

### Root Cause (confirmed via diagnostic test)

**`ChapterRepository::save` and the `chapters` DB table were missing `start_index` and `end_index` columns.**

The `Chapter` domain struct (`storage::models::Chapter`) has `start_index: i64` and `end_index: i64`, but:
1. The `chapters` SQL table (migration `20240506000000_init.sql`) defined only `id, book_id, title, chapter_index, cached_at, level` — no `start_index`/`end_index`
2. `ChapterRepository::save` INSERTed only those 6 columns, never storing the byte offsets
3. When `get_chapter_bounds` called `find_by_index` → `SELECT * FROM chapters`, `sqlx` mapped missing columns as `0` for the `i64` fields
4. `read_text_range(0, 0)` hit `start >= end` guard → returned `""`
5. `PageStreamer::new("", config)` → 0 pages

### Fix

Two-part fix applied:

1. **Migration** `20240608000001_add_chapter_bounds.sql`:
   ```sql
   ALTER TABLE chapters ADD COLUMN start_index INTEGER NOT NULL DEFAULT 0;
   ALTER TABLE chapters ADD COLUMN end_index INTEGER NOT NULL DEFAULT 0;
   ```

2. **`ChapterRepository::save`** — INSERT and ON CONFLICT UPDATE SET now include `start_index` and `end_index` with bindings to the domain struct fields.

### Affected Functions

Both `get_chapter` and `paginate_all_content` / `paginate_chapter` shared the same broken `get_chapter_bounds` call. All three are now fixed. The `extract_chapter_content` fallback (used for PDF/non-TXT formats) was never affected since it re-parses the file directly.

## Other Issues

### `teardownTestStorage` file lock

`PathAccessException` during deletion — SQLite connection still held by FFI layer. **Fix**: Helper implements 3-retry with 500ms/1000ms/1500ms delays.

## Test Results

| Suite | Passed | Skipped | Failed | Notes |
|-------|--------|---------|--------|-------|
| `core_pagination_test.dart` | 14 | 0 | 0 | 2 parse + 4 paginateChapter + 4 paginateAllContent + 4 活着.txt |
| `auto_spacing_test.dart` | 1 | 5 | 0 | Parse test active; 5 pagination tests scaffolded/skipped |
| `cargo test --lib` | 147 | 8 | 0 | 1 new diagnostic test added |

## FRB Code Generation Note

The `flutter_rust_bridge_codegen generate` was re-run to restore API alignment after a `git checkout -- src/api/core.rs` accidentally reverted uncommitted pagination functions (`paginate_chapter`, `get_page_content`, `STREAMER_CACHE`). These were restored manually.

The underlying content extraction bug has been fixed. No further FRB codegen is needed since no API signatures changed.

## Files Created/Modified

| File | Purpose | Status |
|------|---------|--------|
| `test/helpers/integration_test_helper.dart` | Storage init/teardown + file helpers | Created |
| `test/fixtures/mixed_cjk_latin.txt` | Mixed CJK-Latin fixture (~1550B, unused) | Created |
| `test/fixtures/pure_cjk.txt` | Pure CJK fixture (~1460B, unused) | Created |
| `test/fixtures/活着.txt` | Real-world Chinese novel (~284KB) for live-book tests | Moved from project root |
| `test/features/reader/core_pagination_test.dart` | Parse → paginate → content pipeline (14 tests) | Created |
| `test/features/reader/auto_spacing_test.dart` | CJK-Latin auto-spacing behavior (1 active + 5 scaffolded) | Created |
| `rust/migrations/20240608000001_add_chapter_bounds.sql` | Add start_index/end_index to chapters table | Created |
| `rust/src/storage/repos/chapter_repo.rs` | INSERT now binds start_index/end_index | Modified |
| `rust/src/api/core.rs` | Added STREAMER_CACHE, paginate_chapter, get_page_content | Restored |
| `rust/src/text/constants.rs` | CHAPTER_PATTERN_ZH expanded with more heading patterns | Modified |
| `rust/src/frb_generated.rs` | Regenerated to match current API | Regenerated |
| `lib/src/rust/` (generated Dart) | Regenerated to match current API | Regenerated |
