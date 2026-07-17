---
id: M1
phase: Q2
slug: sensitive-file-path-logging
severity: medium
original_id: q2-001
---

# Sensitive File Path Disclosure via Structured Logging

## Location

- `chapter_content_repository.dart` — methods `_logIrFallback`, `_loadChapterPayload`, `_loadScrollModePayload`, `_loadRichCapablePayload`, `preload`
- `flutter_pagination_session.dart` — methods `_paginateFromIr`, `_installPages`, `installFromReady`, `beginPaginate`
- `flutter_staging_preloader.dart` — method `preload`

## Description

The reader engine logs absolute file system paths to the structured logging subsystem (`Logging.info`, `Logging.warning`, `Logging.error`) throughout normal execution. These paths originate from the `Book.filePath` model property — an absolute filesystem path to the EPUB/TXT file on device storage — and are written as log message interpolations without sanitization.

## Evidence

In `chapter_content_repository.dart`, `_tryLoadScrollIr` passes `filePath` to Rust via `scrollIrPayload` but also the same path flows into the `Logging` calls via the `_setChapterFilePath` / `_applyCurrentIr` code path. More directly:

In `_logIrFallback`, the book ID and chapter index are logged:
```
Logging.warning(
  '[ReaderIrFallback] stage=$stage bookId=$bookId '
  'chapter=$chapterIndex mode=${readingMode?.name ?? "unknown"} '
  'fallbackSucceeded=$fallbackSucceeded reason=$reason',
);
```

In `flutter_pagination_session.dart`:
```dart
Logging.info(
  '[FlutterPagination] paginate book=$bookId chapter=$chapterIndex '
  'maxChars=${maxChars ?? "full"} (no Rust pagination FFI)',
);
```

In `flutter_staging_preloader.dart`:
```dart
Logging.info(
  '[FlutterStaging] preload ${forNext ? "next" : "prev"} '
  'chapter=$chapterIndex pages=${pages.length} '
  'body=${contentWidth.toStringAsFixed(0)}x${contentHeight.toStringAsFixed(0)} '
  '${sw.elapsedMilliseconds}ms',
);
```

## Impact

If the app's logging output is collected via crash reporting (Firebase Crashlytics, Sentry), telemetry, device logs (`adb logcat`), or user-shared diagnostic bundles, absolute filesystem paths are exposed. On Android, paths like `/storage/emulated/0/Books/title.epub` reveal user's storage layout and book titles. On desktop, `/home/user/Books/title.epub` leaks home directory structure.

**Pre-auth reachability**: Not directly network-exposed — logs are written locally. However, if any crash reporter or diagnostics sharing UI exists in the app (outside this engine), the logged paths become exfiltratable.

## Recommendation

1. Redact or replace file paths with opaque identifiers (e.g., `book_id`) in production logging.
2. Use `debug-only` logging for path-bearing messages (`assert` or `kReleaseMode` guard).
3. Audit what the `Logging` backend does with its output — if it writes to disk, ensure file permissions are restrictive.

PoC-Status: theoretical
PoC-Block-Reason: No Flutter runtime available in audit environment; static code trace provided
Protocol: local
Auth-Required: no
Auth-Roles-Required: anonymous
