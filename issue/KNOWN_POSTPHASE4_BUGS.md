# Phase 4 遗留已知 Bug（2026-07-02 更新）

> 2026-06-27 代码审阅 + 动态分析确认。
> 2026-07-02 更新：Bug A、Bug B 已修复；追加 P1–P5 新确认的 bug 和风险项。

---

## ✅ Bug A — 跨章导航偶尔弹出「加载失败，重试」 — 已修复

### 修复内容（2026-07-02）

1. **stagingPromote 路径跳过冗余 `loadChapterContent`**：用 `Future.value('')` 替代真实 IO 调用，避免无谓双重请求。
2. **catch 块增加 `isStagingPromote` 保护**：stagingPromote 已成功设置信号后，后续错误不再覆盖 `chapterContent` / `_error`。

### 原根因回顾

`ChapterLoadOrchestrator.run()` 中 stagingPromote 路径同时发起了 `loadChapterContent` 冗余 IO；当该 IO 失败时 catch 块覆盖已可见的内容信号。

### 关键改动

| 位置 | 改动 |
|------|------|
| `chapter_load_orchestrator.dart` | `chapterPlainFuture` 对 stagingPromote 使用 `Future.value('')` |
| `chapter_load_orchestrator.dart` | catch 块增加 `isStagingPromote && content.value != null` 保护 |

---

## ✅ Bug B — 翻页后当前页排版跳变 — 已修复

### 修复内容（2026-07-02）

`_syncPaginationSignalsAfterRepaginate` 使用 `_chapterVM.currentCharOffset.value`（当前实际位置）替代 `request.initialCharOffset`（请求时的初始位置），确保 `expandToFullChapter` / `repaginateAfterMetricsBackfeed` 后用户停留在同一文本位置，页码随页边界变化重映射但不跳变内容。

### 关键改动

| 位置 | 改动 |
|------|------|
| `chapter_load_orchestrator.dart` `_syncPaginationSignalsAfterRepaginate` | `currentCharOffset` 替代 `request.initialCharOffset` |

---

## ✅ P1 — `dispose_pagination_session` 缺少 `#[frb(sync)]` — 已修复

`dispose_pagination_session` 添加 `#[frb(sync)]` 标注，FRB 绑定从 `Future<void>` 变为 `void`，Dart 侧调用从异步变为同步。

## ✅ P2 — 模式切换时 session 未 dispose — 已修复

`setReadingMode()` 中非 pagination 模式前调用 `_repo.disposePagination()`，避免 PaginationSession 和 LRU engine 悬空占用内存。

---

## 仍开放的 Bug（2026-07-02 确认，部分已修复）

### P1 — 影响用户可见行为

| # | Bug | 位置 | 现象 | 状态 |
|---|-----|------|------|------|
| 1 | **TOC href fallback 导致章节边界偏移** | `rust/src/parser/epub/toc.rs:81-97` | 部分 EPUB 的 TOC href 未匹配 spine → 均匀分配到剩余 spine | ❌ 仍开放 |
| 2 | **滚动跨章高亮 offset 冲突** | `scroll_mode_renderer.dart` + `highlight_painter.dart` | 多段拼接时相邻章高亮的 charOffset 指向错误位置 | ❌ 仍开放 |
| 3 | **选区工具栏定位不准** | `reader_interaction_layer.dart:53-58` | 左右仍铺满全屏而非跟随选区 X | ❌ 仍开放（Y 已改善） |
| 4 | **WidgetSpan height: double.infinity** | `highlight_painter.dart` | 高亮竖条在某些 TextSpan 上下文引发布局错误 | ✅ 已修复（改为 finite barHeight） |

### P2 — 不直接影响主路径，但存在隐患

| # | Bug | 位置 | 现象 | 状态 |
|---|-----|------|------|------|
| 5 | **Doc 注释与常量不一致** | `rust/src/text/pagination.rs:125-127` | 注释说「50K 字符阈值」，实际 `200_000` | ✅ 已修复（注释更新为 200K） |
| 6 | **`PageStreamer.from_pages()` 硬编码 `is_partial = false`** | `rust/src/text/pagination.rs:173` | 接口语义上调用方无法表达 partial-from-cache | ❌ 仍开放 |
| 7 | **Session dispose 后 store 残留语义不精确** | `rust/src/api/core.rs:333` | LRU 覆盖场景下 evict 的不是原 engine | ❌ 仍开放（已改善） |
| 8 | **End-avoid 标点仅在预处理阶段** | `rust/src/text/typeset.rs` | 行断计算不处理避头尾标点 | ❌ 仍开放 |
| 9 | **HighlightPainter 静态缓存 stale** | `highlight_painter.dart:13-32` | baseStyle 不参与缓存键，样式变更后返回旧缓存 | ✅ 已修复（加入 styleHash） |
| 10 | **Scroll 预加载错误被静默吞掉** | `scroll_boundary_coordinator.dart:93` | `catchError((_) {})` 丧失诊断信息 | ✅ 已修复（添加 Logging） |
| 11 | **Orchestrator preload 错误被静默吞掉** | `chapter_load_orchestrator.dart:738` | `catchError((_) {})` 丧失诊断信息 | ✅ 已修复（添加 Logging） |

### P3 — 代码异味 / 架构债务（当前安全但脆弱）

| # | 问题 | 位置 | 说明 |
|---|------|------|------|
| 12 | **u64 config_hash 截断为 Dart int** | Dart 侧 `toInt()` | 50% 概率 MSB=1 → 负数；同类比较安全但跨系统持久化会 miss |
| 13 | **两套分页 API 路径不统一** | path-based vs handle-based | `PaginationStore` 已统一存储，但 path-based `paginate_chapter` + `get_page_content` 仍存在 |
| 14 | **Block Paginator chunk 边界不考虑图片跨 chunk** | `block_paginator.rs:416` | `CHUNK_BLOCK_COUNT=200` 机械分块，大图片在边界附近时 merge 仅调 page_index 不重排版 |

---

## ✅ 已在代码演进中解决的问题（无需手动修复）

| # | 原问题 | 现状 |
|---|--------|------|
| EPUB 导入 `file_size: 0` | `rust/src/parser/epub/parse.rs:78` 现使用 `std::fs::metadata` 获取真实大小 |
| STREAMER_CACHE 容量=4 | `PaginationStore` 容量已升为 16 (`PAGINATION_ENGINE_CACHE_CAPACITY`) |
| `PaginationEngine.paginateApproximate` 后备路径 | 已从代码库移除，`ReaderRepositoryInterface` 无此方法 |
| `dispose_pagination_session` async → sync | 已添加 `#[frb(sync)]`，FRB 绑定为同步调用 |
| WidgetSpan height: infinity | 高亮竖条改为 `(fontSize × lineHeightMultiplier)` 的有限高度 |
| Doc 注释 50K vs 200K | 注释已更新为「200K 字符」 |
| HighlightPainter 缓存不含 style | `baseStyle.hashCode` / `span.style.hashCode` 加入缓存键 |
| Scroll/Orc preload 静默 catchError | 添加 `Logging.debug` 日志输出 |

## ✅ 本次手动修复的问题（2026-07-02 第二轮）

| # | 修复 | 改动文件 |
|---|------|----------|
| Bug A 跨章错误重试 | stagingPromote 路径跳过冗余 IO + catch 块保护 | `chapter_load_orchestrator.dart` |
| Bug B 翻页跳变 | `_syncPaginationSignalsAfterRepaginate` 用当前 charOffset | `chapter_load_orchestrator.dart` |
| P1 dispose sync | `#[frb(sync)]` + FRB 重新生成 | `rust/src/api/core.rs` |
| P2 mode switch dispose | `setReadingMode` 非 pagination 前调 `disposePagination()` | `reader_view_model.dart` |
| P1-4 WidgetSpan infinity | `barHeight = fontSize × height` 替代 `double.infinity` | `highlight_painter.dart` |
| P2-5 Doc comment | 注释 50K → 200K | `pagination.rs` |
| P2-9 缓存 stale | `styleHash` 加入缓存键 | `highlight_painter.dart` |
| P2-10/11 静默 catchError | 添加 `Logging.debug` | `scroll_boundary_coordinator.dart`, `chapter_load_orchestrator.dart` |
