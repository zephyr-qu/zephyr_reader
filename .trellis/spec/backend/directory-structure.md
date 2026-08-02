# Directory Structure

> How backend code is organized in this project.

---

## Overview

The Rust backend follows a three-layer architecture:

1. **`api/`** — FRB thin wrapper layer (FFI boundary, delegates to domain services)
2. **`domain/`** — Business logic layer (flat module structure)
3. **`infra/`** — Infrastructure layer (storage pool, FRB init)

Plus supporting modules:

- **`parser/`** — File format parsers (EPUB only; TXT support removed 2026-08)
- **`common/`** — Shared types, error definitions, security utilities

> 2026-08 update: `note/`, `vocabulary/`, `bilingual/`, `search/`, `wordlist/`, `pipeline/`, and the TXT parser were removed in the Readium-only cleanup. The doc below reflects the current tree.

---

## Directory Layout

```
rust/src/
├── api/                      # FRB thin wrapper — FFI boundary
│   ├── mod.rs
│   ├── backup.rs             → domain::backup::service
│   ├── book.rs               → domain::book::service
│   ├── bookmark.rs           → domain::bookmark::service
│   ├── category.rs           → domain::category::service
│   ├── cover.rs              → domain::cover::service
│   ├── dictionary.rs         → domain::dictionary::service
│   ├── engine_position.rs    → domain::engine_positions::service
│   ├── progress.rs           → domain::progress::service
│   ├── session.rs            → domain::sessions::service
│   └── stats.rs              → domain::stats::service
│
├── domain/                   # Flat business logic modules
│   ├── mod.rs
│   ├── book/                 # Book management
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   ├── service.rs         # BookDetail aggregation, cascade delete, parse
│   │   └── book_repo.rs
│   ├── bookmark/             # Bookmarks (positions in Readium locators)
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   └── bookmark_repo.rs
│   ├── category/             # Book categories
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   └── category_repo.rs
│   ├── chapter/              # Book chapters
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   └── chapter_repo.rs
│   ├── cover/                # Cover extraction
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   ├── service.rs         # extract + save-to-DB + cleanup-on-failure
│   │   └── engine.rs
│   ├── dictionary/           # Dictionary & MDict engine (active: lookup/suggest)
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   ├── service.rs
│   │   ├── dictionary_repo.rs
│   │   └── engine.rs
│   ├── engine_positions/     # Readium Locator JSON hints (per-book, overwrite)
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   └── engine_position_repo.rs
│   ├── progress/             # Reading progress (logical projection)
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   └── progress_repo.rs
│   ├── sessions/             # Reading sessions
│   │   ├── mod.rs
│   │   ├── models.rs
│   │   ├── service.rs         # Business logic, delegates to repo
│   │   └── session_repo.rs
│   └── stats/                # Reading statistics (aggregated from sessions)
│       ├── mod.rs
│       ├── models.rs
│       └── stats_repo.rs
│
├── parser/                   # File format parsers
│   ├── mod.rs
│   ├── registry.rs
│   ├── types.rs
│   └── epub/                 # EPUB parser (entry extraction, TOC, assets)
│       ├── mod.rs
│       ├── archive_reader.rs
│       ├── asset_registry.rs
│       ├── entry_extractor.rs
│       ├── parse.rs
│       └── toc.rs
│
├── infra/                    # Infrastructure
│   ├── mod.rs
│   ├── init.rs               # FRB init / runtime bootstrap
│   └── manager.rs            # Storage pool management
│
├── common/                   # Shared types
│   ├── mod.rs
│   ├── error.rs              # AppError (all FFI errors map to variants)
│   └── security.rs
│
└── frb_generated.rs          # FRB codegen output (do not edit by hand)
```

## Invariants

- FFI-exported functions are `pub fn xxx(...) -> Result<T, AppError>`; no panic crosses the FFI boundary.
- `reading_stats` is written ONLY by `create_session` aggregation — no direct write entry (per ADR / invariant).
- `engine_positions` is an engine-private position hint (Locator JSON), not part of the domain persistence model (per ADR-019).
- FRB generated files (`frb_generated.rs`, `lib/src/rust/`) must never be hand-edited; regenerate via `flutter_rust_bridge_codegen generate`.
