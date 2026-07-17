# Unauthenticated Surface — piolium Lite Q2

**Generated**: 2026-07-17  
**Target**: `F:/App/zephyr_reader/rust/src/api`

> **Architecture Note**: This is a **local-only Flutter + Rust application** communicating via `flutter_rust_bridge` (FRB) in-process IPC. There is no network service, HTTP listener, or network-accessible API. The concept of "anonymous attacker" does not apply in the traditional sense because:
> - There is no network-facing surface
> - All functions are callable from the Flutter UI layer (Dart code running in the same process)
> - Any attacker who has code execution in the Flutter layer (via XSS from WebView, compromised dependency, or local access) already has full process access

## Entry Points (FRB-Public Functions)

All `#[frb]` annotated functions are entry points callable from Flutter:

### books (book.rs)
| Function | Parameters | Why-pre-auth | Notes |
|----------|-----------|--------------|-------|
| `get_book_detail` | `book_id: String` | by-design (local app) | Reads single book |
| `list_books` | — | by-design | Full book list |
| `list_bookshelf_books` | `category_id`, `status`, `sort_by`, `sort_order` | by-design | Sorted bookshelf |
| `upsert_book` | `book: Book` | by-design | Create/update book |
| `delete_book` | `book_id`, `covers_dir` | by-design | Destructive; no confirmation |
| `import_book` | `file_path: String` | by-design | File import |
| `create_web_book` | `title`, `author`, `file_path`, ... | by-design | Creates book entry |
| `get_epub_metadata` | `file_path: String` | by-design | EPUB metadata extraction |
| `get_processed_epub_image_bytes` | `file_path`, `asset_id`, `max_width_px` | by-design | Image processing |
| `get_processed_epub_image` | `file_path`, `asset_id`, `max_width_px` | by-design | Image + cache |
| `search_books` | `keyword: String` | by-design | Title/author search |
| `search_bookshelf_books` | `keyword: String` | by-design | Search with progress |

### reading (reader.rs)
| Function | Parameters | Why-pre-auth | Notes |
|----------|-----------|--------------|-------|
| `get_chapter` | `file_path`, `chapter_index` | by-design | Raw text (no book_id resolution) |
| `get_chapter_plain` | `book_id`, `chapter_index` | by-design | Text via DB path |
| `get_chapter_content_ir` | `book_id`, `chapter_index` | by-design | IR via DB path |

### search (search.rs)
| Function | Parameters | Why-pre-auth | Notes |
|----------|-----------|--------------|-------|
| `init_search_engine` | — | by-design | FTS5 init |
| `index_chapter` | `book_id`, `chapter_id`, ... | by-design | Index content |
| `search` | `book_id`, `query`, `limit` | by-design | FTS5 search |
| `search_all_books` | `query`, `limit`, `offset` | by-design | Cross-book search |

### backup (backup.rs)
| Function | Parameters | Why-pre-auth | Notes |
|----------|-----------|--------------|-------|
| `export_database` | `dest_path: String` | by-design | Full data export |
| `restore_database` | `backup_path: String` | by-design | Full data restore |
| `inspect_backup` | `backup_path: String` | by-design | Read manifest |

### dictionary (dictionary.rs)
| Function | Parameters | Why-pre-auth | Notes |
|----------|-----------|--------------|-------|
| `init_dictionary` | `mdx_path`, `mdd_path` | by-design | Open arbitrary file |
| `close_dictionary` | — | by-design | Clear engine |
| `lookup_mdict` | `word: String` | by-design | Query |
| `extract_audio` | `audio_key: String` | by-design | Audio extraction |

## Pre-auth Path Traversal Concerns

The following findings from Q2 are **pre-auth reachable** (i.e., callable without any prior action or authentication):

| Finding | Entry Point | Pre-auth? | Elevation |
|---------|------------|-----------|-----------|
| q2-001 — Cover extraction path traversal | `extract_book_cover`, `extract_and_save_cover` | ✅ yes | none needed (already reachable) |
| q2-002 — delete_book path traversal | `delete_book` | ✅ yes | none needed |
| q2-004 — Dictionary unvalidated path | `init_dictionary` | ✅ yes | none needed |
| q2-008 — No authorization | ALL functions | ✅ yes | none needed |

**Pre-auth severity elevation**: None needed — all findings are already classified based on local-app threat model. In a network-facing context, q2-001 and q2-002 would elevate to **critical**.

## <coverage gap>

- Route-level access control: not applicable (no HTTP routing)
- Auth middleware: not applicable (no network service)
- The Flutter layer's UI state management is outside the Rust codebase — the Rust library cannot enforce which functions the Flutter layer calls, at what time, or in what order
- No access token, session, or audit log exists anywhere in the codebase

## Conclusion

This application has **no network-facing surface**. All "authentication" is implicitly provided by the OS process boundary (only the Flutter app can call FRB functions). The most impactful findings (q2-001, q2-002) affect the filesystem and require the attacker to already have code execution in the Flutter layer or control over file selection dialogs.
