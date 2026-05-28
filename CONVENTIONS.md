# Zephyr Reader AI Coding Conventions

## Architecture & Layering
- **Clean Architecture**: Strictly follow 4 layers (domain/data/application/page) for `reader`, `article`, `home`, `profile`, `statistics`, `search`, `sync`, `vocabulary`.
- **Bookshelf Exception**: `bookshelf/domain/models/` is intentionally empty. Business logic lives in Rust. Do NOT create Dart domain models for bookshelf.
- **DI**: Use GetIt + Injectable. Always bind interfaces to implementations in `di/service_locator.dart`.

## Rust Boundary (FFI)
- **Rust Owns**: Parsing (EPUB/PDF/TXT), FTS5 search, text segmentation, file I/O, caching, heavy computation.
- **Flutter Owns**: UI rendering, animations, gestures, platform channels, in-memory UI state (signals).
- **Data Transfer**: Use flat DTOs. Prefer primitive types. Timestamps use `DateTime<Utc>` (chrono) despite FRB overhead.
- **Error Handling**: Rust must return `Result<T, E>`. Never panic. Map errors to Dart exceptions via FRB.
- **No UI Strings in Rust**: All user-facing strings must be in Flutter l10n (`lib/l10n/app_*.arb`). Rust logs/errors use English only.

## State Management
- Use `signals` + `useSignals` for reactive state.
- Avoid `setState` except for local widget animation state.
- ReaderViewModel is being split; new reader features should go into dedicated controllers (e.g., `ReaderSettingsController`, `AnnotationController`).

## Testing
- Rust: Write integration tests in `rust/tests/` for all new API endpoints. Unit tests in same file for pure logic.
- Dart: ViewModel unit tests required. Widget tests optional but encouraged for complex UI.
- Performance: Critical paths (EPUB open, FTS search) must have benchmarks in `rust/benches/`.