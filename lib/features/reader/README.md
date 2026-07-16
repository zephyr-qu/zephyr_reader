# Reader Feature

架构规划文档索引：[doc/README.md](../../../doc/README.md)（含引擎优化、跨章预加载等设计文档）。

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

```
ReaderShell → ReaderViewModel (facade)
  → ChapterViewModel (加载、导航、分页滚动协调)
    → PaginationCoordinator / ScrollBoundaryCoordinator / AutoScrollController
    → ChapterContentRepository / PaginationEngine / ProgressRepository
    → Rust FFI
```

## Lifecycle

- `ReaderSession` is scoped per book open (not a global singleton).
- `ReaderRepository` is created per `ReaderSession` (not shared across books).
- `PaginationSession` is scoped per chapter; disposed on chapter change or session end.

### Intent 自动推导

`ChapterLoadOrchestrator.run()` 不再依赖调用方传递 `ChapterPaginationIntent`，
改为在 run 开头通过 `resolveIntent()` 自动推导：

```
  loadChapter 开始
     │
     ├─ session 无效（hash null / descriptors 空 / 换章）→ normalLoad
     │
     └─ session 有效
           │
           ├─ configHash 变化 → configReload（in-place repaginate）
           │
           └─ configHash 一致 → expandOnly（跳过 full expand 如已全量）
```

**session 有效**：`sessionConfigHash != null`、`descriptors` 非空、
`sessionChapterIndex == request.chapterIndex`（新增字段）。

| 推导 intent      | 默认 preserveContent | 说明 |
|-----------------|---------------------|------|
| `normalLoad`    | `false`             | 换章默认清旧内容 |
| `configReload`  | `true`              | 设置重载保留当前页 |
| `expandOnly`    | `true`              | retry 保留已渲染内容 |

调用方可通过 `preserveContent: true` 覆盖默认行为（如 `ChapterViewModel` 跨章节翻页）。

### `configReload` 路径

1. `resolveIntent` 确保 session 有效
2. `await calibFuture` + 写入 `_pagination.calibration.value`
3. `repaginateInPlace(maxChars: 2000)`（同一 handle 升级 config）
4. 按 `request.initialCharOffset + 新 descriptors` 重算 `pageIndex`
5. `preserveContent` 默认 `true`，避免排版变更闪 loading
6. full expand 后续由 `expandToFullChapter` 继续

### P4-4 Metrics 回传（ADR-013）

首屏 partial paginate 后、`endOfFrame` 从当前页 plain text 采样 TextPainter 字宽；
若相对 baseline 漂移 > 3%：

1. 更新 `_pagination.calibration`
2. partial 章：`expandToFullChapter` 自动带新 calibration
3. 已全量首屏：调用 `applySessionCalibration` → Rust repaginate + sled 新 config_hash

Staging promote 路径跳过回传（缓存 session 已分页）。

### `PaginationSession` lifecycle

- `dispose()` 释放 Rust 会话并清空本地缓存（含 `sessionChapterIndex` /
  `sessionIsPartial`）。
- Rust 侧 `dispose_pagination_session` 同步驱逐 `STREAMER_CACHE` 副本。
- `_runConfigReload` **不**调 `disposePagination`；handle 沿用到下次换章。

### `pageContent` fetch-on-miss

`PaginationSession.pageContent(i)` 在 cache miss 时**同步**从 Rust session
拉取（`get_session_page_content`，纯内存操作）并写入本地缓存，
renderer 不再依赖 `ensureWindow` 预取才能显示内容：

```
Renderer → pageContent(i) → cache miss → _fetchAndCachePage(i)
  → getSessionPageContent sync → put + return
```

- 预取路径（`_preloadPageRange`、`_prefetchSurrounding`、`ensureWindow`）
  统一使用 `_fetchAndCachePage`。
- `dispose()` 后 miss 返回 `null`（renderer 走占位，与历史行为一致）。
- config repaginate 后 `_contentCache.clear()` 已有；下次 `pageContent` 自动 refetch。
- **不在 `pageContent` 内调用 `trimAround`**（避免 build 路径副作用）。
