# Reader Feature

Modular reader feature organized by subdirectories.

## Structure

| Directory | Responsibility |
|-----------|----------------|
| `core/` | Reading session, chapter loading, pagination coordination, navigation, progress |
| `rendering/` | Scroll/paginated/bilingual renderers, highlight painting, page curl |
| `annotations/` | Bookmarks, highlights, notes UI and view models |
| `translation/` | Bilingual mode, translation API, providers, cache |
| `settings/` | In-reader settings panels (typesetting, display, more, assist) |
| `navigation/` | Chapter drawer, bookmark list, TOC |

## Data flow

```
ReaderShell → ReaderViewModel (facade)
  → ChapterLoader / PaginationCoordinator / ChapterNavigator
  → ChapterContentRepository / PaginationSession / ProgressRepository
  → Rust FFI
```

## Lifecycle

- `ReaderSession` is scoped per book open (not a global singleton).
- `PaginationSession` is scoped per chapter; disposed on chapter change or session end.
- Global reading preferences live in `lib/core/reader/` (`ReaderConfig`, fonts, TTS).

## Conventions

- Pass `ReaderViewModel` to child widgets; subscribe locally with `useSignalValue`.
- Do not use intermediate binding DTOs between VM and UI.
- Application layer must not import from `rendering/`.
