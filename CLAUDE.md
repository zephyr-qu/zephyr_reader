# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zephyr Reader is an Android bilingual (Chinese/English) offline novel reader built with **Flutter + Rust**. Pure local storage, no backend, no ads, no data collection.

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Flutter** | 3.22.0+, Dart 3.10.7+ |
| **Rust** | 1.75.0+ (in `rust/`) |
| **FFI Bridge** | flutter_rust_bridge 2.11.1 |
| **State Management** | signals_flutter, signals_hooks |
| **Dependency Injection** | get_it + injectable |
| **Database** | Drift (SQLite) |
| **Routing** | go_router |
| **Network** | dio + retrofit |
| **Target** | Android 8.0+ (API 26+) |

## Quick Start Commands

```bash
# Install Flutter dependencies
flutter pub get

# Generate code (injectable, drift, freezed, json_serializable, retrofit)
dart run build_runner build --delete-conflicting-outputs

# Generate Rust bridge code
cd rust && flutter_rust_bridge_codegen build

# Run app (debug)
flutter run

# Build release APK
flutter build apk --release --target-platform android-arm64,android-arm,android-x64 --split-per-abi

# Code analysis
flutter analyze

# Run tests
flutter test
flutter test integration_test/

# Rust commands
cd rust
cargo check          # Check Rust code
cargo build          # Build debug
cargo build --release  # Build release
cargo test           # Run Rust tests

# Clean
flutter clean
```

## Architecture

### Directory Structure

```
zephyr_reader/
├── lib/                      # Flutter main
│   ├── main.dart             # App entry
│   ├── app.dart              # App root widget
│   ├── core/                 # Core infrastructure
│   │   ├── network/          # Dio config, interceptors
│   │   ├── local/            # SharedPreferences, FileStorage
│   │   ├── routing/          # GoRouter config
│   │   ├── theme/            # ThemeData, DesignTokens
│   │   ├── database/         # Drift tables, database
│   │   ├── performance/      # Cache, optimizer
│   │   └── utils/            # Logging
│   ├── di/                   # Dependency injection
│   │   ├── app_module.dart
│   │   ├── database_module.dart
│   │   └── service_locator.dart
│   ├── domain/               # Domain models
│   │   └── models/           # Book, Chapter, Bookmark, etc.
│   └── features/             # Feature modules
│       ├── article/          # Article reading
│       ├── auth/             # Authentication
│       ├── bookshelf/        # Book management
│       ├── home/             # Home page
│       ├── profile/          # User profile
│       ├── reader/           # Core reading
│       ├── search/           # Full-text search
│       ├── statistics/       # Reading stats
│       └── sync/             # WebDAV sync
├── rust/                     # Rust core engine
│   ├── src/
│   │   ├── api/              # FFI API layer
│   │   ├── parser/           # TXT/EPUB/PDF parsers
│   │   ├── text_process/     # Line breaking, typesetting
│   │   ├── stream/           # Stream loading
│   │   └── search/           # Full-text search
│   └── Cargo.toml
├── rust_builder/             # Flutter plugin wrapper
└── native/reader_core/       # FRB config
```

### Feature Module Structure

```
features/<feature>/
├── application/          # ViewModels (signals_flutter)
│   └── <feature>_view_model.dart
├── data/
│   ├── <feature>_api.dart    # Retrofit API definition
│   └── repositories/         # Repository implementations
├── domain/
│   └── repositories/         # Repository interfaces
└── page/                 # UI pages
```

### Core Patterns

**State Management (signals_flutter):**
```dart
// Signal
final count = signal(0);

// Computed
final doubleCount = computed(() => count.value * 2);

// Async signal
final user = asyncSignal<User?>(AsyncState.data(null));

// Effect
effect(() => print('User: ${user.value}'));

// In Widget
Watch(builder: (context) => Text('${count}'));
```

**ViewModel Pattern:**
```dart
@injectable
class AuthViewModel {
  final AuthRepository _repo;
  AuthViewModel(this._repo);

  final user = asyncSignal<User?>(AsyncState.data(null));
  final email = signal('');

  Future<void> login() async {
    user.value = AsyncState.loading();
    try {
      user.value = AsyncState.data(await _repo.login(email.value));
    } catch (e) {
      user.value = AsyncState.error(e);
    }
  }
}
```

**Database (Drift):**
```dart
// Query
final books = await db.dbBooks.get();

// Insert
await db.dbBooks.insert(book, mode: InsertMode.insertOrReplace);

// Transaction
await db.transaction(() async { ... });
```

**Rust FFI:**
```rust
// Rust function with FRB
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

// Call from Dart
final result = RustLib.instance.greet(name: "World");
```

## Key Conventions

1. **Feature-first organization**: Each feature is self-contained with its own data/domain/application/page layers
2. **Repository pattern**: Domain layer defines interfaces, data layer provides implementations
3. **ViewModel with signals**: All ViewModels use signals_flutter for reactive state
4. **Freezed for models**: Domain models use `@freezed` for immutability
5. **Drift for database**: Type-safe SQL with Drift ORM
6. **Logging**: Use `Logging` utility class for all debug/error logging (no `print` or `debugPrint`)
7. **Error handling**: Use try-catch with proper error logging via `Logging.error()`
8. **Performance**: Large files (>10MB) use chunked loading with LRU caching
9. **Code style**: Follow analysis_options.yaml rules (prefer_single_quotes, require_trailing_commas, sort_constructors_first, etc.)

## Existing Skills/Conventions

The project uses `.qwen/skills/` for AI assistant guidance on:
- Flutter architecture (Clean Architecture, feature-first)
- signals_flutter state management
- Rust integration patterns
- UI/UX best practices
- Drift database patterns

## Database Schema

The app uses Drift with these tables:
- `DbBooks` - Book metadata
- `DbChapters` - Chapter data
- `DbBookmarks` - User bookmarks
- `DbReadingProgress` - Reading progress per book
- `DbReadingHistory` - Reading history
- `DbLayoutCaches` - Typesetting cache
- `DbReadingStats` - Reading statistics
- `DbReadingSessions` - Reading session records
- `DbDailyReadingRecords` - Daily reading records

## Rust Core Modules

| Module | Purpose |
|--------|---------|
| `parser/` | TXT/EPUB/PDF parsing, encoding detection |
| `text_process/` | Chinese/English line breaking, typesetting |
| `stream/` | Lazy loading, memory-mapped file reading |
| `search/` | Full-text search with jieba-rs |
| `api/` | FFI interface for Flutter |
