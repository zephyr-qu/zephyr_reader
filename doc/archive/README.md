# Doc Archive — 已完成规划

本目录存放**已完成**的规划文档，仅作历史参考。

活跃规划索引见 [doc/README.md](../README.md)（引擎优化）；架构治理见 [READER_ARCH_GOVERNANCE_PHASES.md](../READER_ARCH_GOVERNANCE_PHASES.md)。

---

## [plan-unify-typeset-truth.md](./plan-unify-typeset-truth.md) ✅

**目标**：以 Rust `PageDescriptor` + `PaginationSession` 为唯一排版真理，消除 Dart `paginateApproximate` 生产路径。

**完成内容**：
- Phase 1：新增 `firstScreenMaxChars = 2000` 快速首屏 API
- Phase 2：Orchestrator 流水线（calib + firstSpine 并行 → `beginPaginate(2000)` → full upgrade）
- Phase 3：Renderer / Navigator / ReaderContent 仅 `descriptors`，删除 `PageInfo` 回退
- Phase 4：`paginateApproximate` deprecated；`preloadNextChapterFirstPage` 改为纯文本预取
- Phase 5：测试更新

---

## [planb-pagination-cache-consolidation.md](./planb-pagination-cache-consolidation.md) ✅

**目标**：收敛 Rust 3 层 + Dart 4 层分页缓存/会话路径。

**完成内容**：
- P0：dispose 生命周期可达；Rust `STREAMER_CACHE` 同步驱逐
- P1：抽出 `PageContentCache`（center±5 窗口）；`RustPaginationSession` 瘦身
- P2：API 合并 `beginPaginate(maxChars:)` / `expandToFullChapter`；旧方法 deprecated
- P3：删除 `_approximatePages` / `currentPages` / `getPageContent` 生产路径
- P4：Repository scoped per `ReaderSession`（per-session `ReaderRepository`）
- P5：Rust session 持有 `PageStreamer` 克隆，直接读取；`dispose` 驱逐

---

## [planc-session-config-hot-reload.md](./planc-session-config-hot-reload.md) ✅

**目标**：在不 dispose session 的前提下重排同章节（新 config 走 in-place repaginate）。

**完成内容**：
- Phase 1：Rust `apply_session_repagination` 原子更新 `config + streamer`；新增 `repaginate_session` FFI；`paginate_session_full(handle, Option<config>)`；修复 `..entry` 漏 `config` bug
- Phase 2：Dart `RustPaginationSession` `_sessionConfigHash` 跟踪 + `repaginateInPlace(params)`；`expandToFullChapter` 传新 config
- Phase 3：`ChapterPaginationIntent { normalLoad, configReload, expandOnly }` 取代 `restartSession: bool`；`run()` switch(intent)
- Phase 4：测试 + integration test `test_repaginate_font_size_change_preserves_handle`

**Polish**（后续小修）：
- `repaginateInPlace` fallback 用真实 `bookId`/`chapterIndex`
- `_debounceReloadChapter` 传 `preserveContent: true`（避免排版变更闪 loading）
- `_runConfigReload` 按 `currentCharOffset + 新 descriptors` 重算 `pageIndex`
- `expandToFullChapter` hash 未变时传 `config: null` 复用 session config（避免重复 validate）

---

## 整体架构成果

1. **单一排版真理** — Rust `PageDescriptor[]` + `PaginationSessionHandle` + Rust `PageStreamer`
2. **单一 Dart 页缓存** — `PageContentCache`（center±5 滑动窗口）
3. **同会话 config 热更新** — `repaginate_session` 不 dispose handle，按 `configHash` 决策
4. **意图化编排** — `ChapterPaginationIntent` 取代 `restartSession: bool`
5. **Session 生命周期闭环** — dispose 同步驱逐 `STREAMER_CACHE` + 清 6 个字段
6. **Per-session Repository** — 不再单例，跟随 `ReaderSession` 生命周期

**最终验证**：
- `dart analyze lib/ test/features/reader/` — 0 errors (6 pre-existing)
- `flutter test test/features/reader/` — 112/112 + 36 skipped
- `cargo test pagination_session_test` — 9/9
