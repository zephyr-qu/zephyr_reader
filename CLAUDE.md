# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zephyr Reader is a bilingual (Chinese/English) offline novel reader app for Android, built with a **Flutter + Rust** hybrid architecture. The app is fully local -- no backend, no ads, no data collection -- with WebDAV sync as the sole network feature. Connected via `flutter_rust_bridge` (FRB).

## Essential Commands

### Code Generation (run after modifying models, DI, DB schema, or FFI)
```bash
# Dart code generation (Freezed, injectable, drift, retrofit, etc.)
dart run build_runner build --delete-conflicting-outputs

# Rust-Dart FFI bindings
flutter_rust_bridge_codegen build
```

### Flutter
```bash
flutter pub get                     # Install dependencies
flutter run                         # Run on device (debug)
flutter analyze                     # Static analysis
flutter test                        # Run all unit tests
flutter test <path>                 # Run a single test file
flutter test integration_test/      # Integration tests (includes rust engine tests)
flutter build apk --release         # Build release APK
flutter clean                       # Clean build artifacts
```

### Rust
```bash
cd rust/
cargo check                         # Compile check
cargo build --release               # Release build
cargo test                          # Run Rust tests
```

## Architecture

### Flutter (lib/)
- **Entry**: `main.dart` → `app.dart` (MaterialApp.router with go_router)
- **Routing**: `lib/core/routing/` -- go_router with ShellRoute for MainLayout (bottom/side nav). Reader page is standalone, bypassing MainLayout.
- **State Management**: `signals_flutter` for reactive state; `flutter_hooks` + `signals_hooks` in widgets
- **DI**: `get_it` + `injectable` with code generation in `lib/di/`
- **Database**: `drift` (SQLite ORM) -- tables for books, chapters, bookmarks, reading progress, history, sessions, stats, layout cache
- **Security**: `flutter_secure_storage` for WebDAV credentials; `shared_preferences` for general config
- **Features** (`lib/features/`): home, bookshelf, reader, search, article, auth, profile, sync, statistics -- each organized by domain/data/application/page sub-layers
- **Shared UI** (`lib/shared/`): reusable widgets (adaptive_layout, book_cover, chapter_content, etc.)
- **FFI bindings** (`lib/src/rust/`): FRB-generated bindings to Rust engine
- **Generated code** (`lib/gen/`): flutter_gen asset imports

### Rust (rust/src/)
- **Parser** (`parser/`): TXT, EPUB, PDF file parsers with encoding auto-detection (UTF-8, GBK, GB2312, Big5 via `encoding_rs` + `chardetng`)
- **Text Processing** (`text_process/`): bilingual layout, line-breaking, typesetting, chapter detection, rich-text rendering
- **Stream** (`stream/`): page-based streaming for large file handling
- **Search** (`search/`): SQLite-backed full-text search with `jieba-rs` Chinese tokenization
- **Storage** (`storage/`): in-memory progress/bookmark storage with LRU cache
- **FFI Types** (`ffi/`): standardized error handling, FRB-generated type bindings
- **API** (`api/`): FFI-exposed functions consumed by Flutter

### Key Patterns
- **Feature-first architecture**: each feature in `lib/features/` is self-contained with its own data, domain, and presentation layers
- **Domain models** use `@freezed` for immutable data classes with JSON serialization
- **Rust handles heavy computation** (parsing, text processing, search); **Flutter handles UI and persistence** (Drift SQLite)
- **FRB** manages type-safe communication between layers

## Important Notes
- `build.yaml` restricts code generation scope to specific `lib/` subtrees
- `flutter_rust_bridge.yaml` configures the FRB build (rust_root: `rust/`, dart_output: `lib/src/rust`)
- Rust `Cargo.toml` uses `cdylib` + `staticlib` + `rlib` crate types for Flutter FFI
- The app targets Android API 26+ (Android 8.0)
- `sqlite3.dll` is bundled in the project root for native SQLite support
