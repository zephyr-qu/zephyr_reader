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
- `ReaderRepository` is created per `ReaderSession` (not shared across books).
- `PaginationSession` is scoped per chapter; disposed on chapter change or session end.

### `ChapterPaginationIntent` — 章节分页意图

`run()` 根据显式 intent 决定路径，取代 `restartSession: bool`：

| Intent | 触发场景 | 路径 |
|--------|---------|------|
| `normalLoad` (默认) | 换章 / 无 session | `_runFirstSpine` → `beginPaginate(2000)` → 必要 `expandToFullChapter` |
| `configReload` | 同章 + 排版参数变（设置重载） | in-place `repaginateInPlace`，**不** dispose handle |
| `expandOnly` | 同章 + config 不变（retry / initialize） | 复用 descriptors + 强制 full expand |

`configReload` 路径：
1. 校验 `_contentRepo.sessionConfigHash != null`；无则退回 `normalLoad`
2. `await calibFuture` + 写入 `_pagination.calibration.value`
3. `repaginateInPlace(maxChars: 2000)`（同一 handle 升级 config）
4. 按 `request.initialCharOffset + 新 descriptors` 重算 `pageIndex`
5. 设置 `preserveContent: true`，避免排版变更闪 loading
6. full expand 后续由 `expandToFullChapter` 继续

### `PaginationSession` lifecycle

- `dispose()` 释放 Rust 会话并清空本地缓存（6 个字段）。
- Rust 侧 `dispose_pagination_session` 同步驱逐 `STREAMER_CACHE` 副本。
- `_runConfigReload` **不**调 `disposePagination`；handle 沿用到下次换章。

## Conventions

- Pass `ReaderViewModel` to child widgets; subscribe locally with `useSignalValue`.
- Do not use intermediate binding DTOs between VM and UI.
- Application layer must not import from `rendering/`.
- Use `ChapterPaginationIntent` 而不是 `bool restartSession` 表示加载意图。
