---
id: M2
phase: Q2
slug: file-path-revalidation-gap
severity: medium
original_id: q2-002
---

# File Path Re-validation Gap Between Dart and Rust Boundary

## Location

- `chapter_content_repository.dart` — `_loadChapterPayload`, `_loadScrollModePayload`, `_loadRichCapablePayload`
- `flutter_pagination_session.dart` — `_paginateFromIr`, `_installPages`, `installFromReady`
- `flutter_staging_preloader.dart` — `preload`
- `image_cache.dart` — `EpubBlockImageCache.load`, `EpubBlockImageCache.prefetchBlocks`

## Description

The `filePath` read from the `Book` model via `book_api.getBook(bookId:)` is stored as `_sessionFilePath` and passed to Rust API functions (`reader_api.getChapterContentIr`, `reader_api.getChapterPlain`, `epub_api.getProcessedEpubImageBytes`, `epub_api.getProcessedEpubImage`) without re-validation at the Dart-to-Rust boundary. Each invocation of the Rust API includes `validate_file_path()` (which checks existence + canonicalizes), but:

1. **No active check at the Dart layer** — the Dart code trusts the path stored during book import without verifying it still points to a legitimate location at time of use.
2. **No symlink resolution verification** — `validate_file_path` in `rust/src/common/security.rs` calls `canonicalize()` but does not verify the resolved path is within an expected application directory.
3. **Trust boundary is crossed each call** — Every call from Dart to Rust crosses a trust boundary. Even though import-time validation exists, there is no runtime path integrity check between the `Book` data store and the file-reading APIs.

## Evidence

In `flutter_pagination_session.dart`:
```dart
final book = await _getBook(bookId);
if (book.filePath.isEmpty) {
  throw Exception('FlutterPaginationSession: book not found for bookId=$bookId');
}
_sessionFilePath = book.filePath;
_imageMaxWidthPx = (params.width - 2 * params.padding).round().clamp(1, 4096);
```

Then later, the path is used without re-validation:
```dart
final frbIr = await reader_api.getChapterContentIr(
  bookId: bookId,
  chapterIndex: chapterIndex,
);
```

In `image_cache.dart` — the `_defaultEpubImageLoader` passes `filePath` directly:
```dart
Future<Uint8List> _defaultEpubImageLoader({
  required String filePath,
  required String assetId,
  required int maxWidthPx,
}) => Future.microtask(
  () => epub_api.getProcessedEpubImageBytes(
    filePath: filePath,
    assetId: assetId,
    maxWidthPx: maxWidthPx,
  ),
);
```

## Root Cause

The `Book.filePath` originates from the `import_book` or `create_web_book` service functions. While `import_book` calls `validate_file_path`, the `create_web_book` function accepts an arbitrary `file_path` parameter from the caller without validation (as noted in Rust audit finding q2-007). Once stored, the path is trusted indefinitely.

## Impact

If the book record is compromised (e.g., via SQL injection in bookmark sync, malicious import flow, or crafted web book creation), an attacker-controlled path reaches the Rust file I/O layer. While `validate_file_path` in Rust does canonicalize, it doesn't restrict paths to an application sandbox directory. A path like `/data/data/com.example/databases/zephyr.db` or `/proc/self/fd/...` could be used to read arbitrary files the process has access to, if the Rust API can be called with such paths.

**Pre-auth reachability**: Not directly — requires a compromised book record. The WifiTransferService (outside reader_engine) can import books pre-auth, creating a multi-step attack chain.

## Recommendation

1. Add Dart-side path validation before passing to Rust: verify `filePath` is within an expected base directory (e.g., app's document directory).
2. Add symlink resolution and containment verification to `validate_file_path` in Rust — ensure the canonical path starts with an expected prefix.
3. For `create_web_book` and similar book creation paths, validate `file_path` before storage.

---

## PoC Metadata (Phase Q3)

PoC-Status: executed
PoC-Block-Reason: n/a
Protocol: local
Auth-Required: no
Auth-Roles-Required: n/a

The PoC is a Rust integration test (`poc.rs`) that demonstrates the complete attack chain:
1. Creates a file with sensitive content at an arbitrary temp path
2. Uses `create_web_book` to create a Book record pointing to that path — **no validation**
3. Adds a chapter entry to the database
4. Calls `get_chapter_content_ir` — which internally calls `load_chapter_content_ir` — **no path validation**
5. The sensitive file content is returned in the IR plain_text, proving arbitrary file read

Contrast: `get_chapter_plain` (same API file) correctly returns an error because it calls `validate_file_path` before reading.

Evidence is in `piolium/findings/M2-file-path-revalidation-gap/evidence/`.
