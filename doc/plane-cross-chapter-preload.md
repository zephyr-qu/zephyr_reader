---
name: 跨章无缝翻页预加载
overview: 在 pageTurn 模式下，于当前章阅读时后台预建下一章 PaginationSession（descriptors + 首页 content），使 PageCurlWidget 跨章翻页不白屏、不依赖 firstSpine 纯文本占位。
todos:
  - id: audit-current-preload
    content: 梳理 preloadNextChapterFirstPage / preloadGeneration / PageCurl extendedTotal 现状与缺口
    status: completed
  - id: next-chapter-session-cache
    content: Dart 侧 NextChapterPaginationCache（章 index + descriptors + 可选 handle 策略）
    status: completed
  - id: background-begin-paginate
    content: ChapterNavigator / orchestrator 钩子：当前章 stable 后 beginPaginate(下一章, maxChars=2000)
    status: completed
  - id: pagecurl-handoff
    content: reader_content pageTurn 跨章页使用预加载 descriptors + pageContent；onReachEnd 切换 session
    status: completed
  - id: race-generation
    content: generation / 换章 / configReload 时 invalidate 预加载；快速连翻测试
    status: completed
  - id: tests
    content: chapter_manager + reader_content pageTurn 集成测试
    status: completed
  - id: fix-hardcoded-config
    content: preloadNextChapterStaging 改用实际排版参数替代硬编码 400×600/16px
    status: completed
isProject: false
---

# 跨章无缝翻页（Cross-Chapter Preload）

## 当前实现状态（2026-06-16）

### 已完成的实现

#### 1. NextChapterStaging 数据类

路径：[`lib/features/reader/core/data/next_chapter_staging.dart`](../lib/features/reader/core/data/next_chapter_staging.dart)

```dart
class NextChapterStaging {
  final int chapterIndex;
  final int configHash;
  final List<PageDescriptor> descriptors;
  final String firstPageContent;
  final bool isPartial;

  bool matches(int chapterIndex, int configHash);
}
```

由 `RustChapterContentRepository` 持有，`disposePagination()` / `configReload` / 换书时 `clear()`。

#### 2. 预加载实现（无 handle 的轻量 API）

利用 Rust 现有的 `paginate_chapter`（无 handle，仅写入 STREAMER_CACHE），Dart 侧在 `RustChapterContentRepository.preloadNextChapterStaging` 中：

- `paginateChapter(filePath, chapterIndex, config, maxChars=2000)` → `PaginateResult`
- `getPageContent(filePath, chapterIndex, configHash, 0)` → 首页文本
- 组装为 `NextChapterStaging` 缓存到 `_nextChapterStaging` 字段

预加载配置使用 **实际阅读排版参数**（fontSize/lineHeight/width/height/padding/devicePixelRatio/fontFamily），通过接口链从 `ChapterNavigator` 传入，而非硬编码默认值。

#### 3. 后台触发时机

| 触发点 | 行为 |
|--------|------|
| `_runFirstSpine` 完成后 | `preloadAdjacentFirstPages(centerIndex)` → `preloadNextChapterStaging(bookId, nextIdx, ...)` |
| `configReload` / 换章 | `ChapterLoadOrchestrator.run()` 起始 `clearNextChapterStaging()` |
| 换书 | `loadChapter(0)` → `run()` → `clearNextChapterStaging()` |

#### 4. Generation 竞态防护

```dart
int _stagingGen = 0;

Future<void> preloadNextChapterStaging(...) async {
  final gen = ++_stagingGen;
  // ... async calls ...
  if (gen != _stagingGen) return; // stale → 丢弃
}
```

| 事件 | 动作 |
|------|------|
| 新 `loadChapter` 开始 | `_stagingGen++`，clear staging |
| configReload | `_stagingGen++`，clear staging |
| 用户跳到非 adjacent 章 | `_stagingGen++`，clear staging |
| 快速 nextChapter ×2 | 第二次 load 取消第一次 preload |

#### 5. pageTurn UI 接入

[`reader_content.dart`](../lib/features/reader/page/widgets/reader_content.dart)：

- 虚拟跨章页（`idx >= totalPages`）使用 `dataSource.nextChapterStaging`：
  - 有 staging → 渲染 `staging.firstPageContent` + `staging.descriptors[0].startOffset`
  - 无 staging → 回退到当前章 pageBuilder
- `onReachEnd` → `nextChapter()` → `loadChapter()`（normalLoad，走完全编排路径）
- staging 完成后通过 `preloadGeneration` notifier 触发 UI 重建

[`ReaderRenderDataSource`](../lib/features/reader/core/data/reader_render_data_source.dart) 已包含 `NextChapterStaging? get nextChapterStaging`。

#### 6. 接口链

- `ChapterContentRepository`（domain 接口）— `preloadNextChapterStaging`, `nextChapterStaging`, `clearNextChapterStaging`
- `ReaderRepositoryInterface`（domain 接口）— 同上
- `ReaderRepository`（实现）— 委托到 `_chapterContent`
- `RustChapterContentRepository`（实现）— 实际业务逻辑 + `_stagingGen` 防护

#### 7. 日志与可观测性

`preloadNextChapterStaging` 包含 `[Timing]` 日志：
- `preloadNextChapterStaging: ${ms}ms (chapter=$idx, isPartial=..., pages=N)`
- `preloadNextChapterStaging complete: ${ms}ms (staging ready for chapter=$idx)`

### 未实现（Phase 2 — handle promote）

若 Phase 1 dispose+recreate 仍然慢，可考虑：
1. Rust `create_pagination_session` 支持 staging 专用 handle 池
2. 换章：`dispose(current)` + assign staging handle → `_handle`

当前 profiling 尚不证明 Phase 1 不够，暂不实现。

## 验收标准

- [x] 当前章读到倒数第 2 页时，下一章 descriptors + 第 0 页 content 在后台就绪（Timing 日志可观测）
- [x] pageTurn 跨章动画期间不再长期空白 Container
- [x] configReload / 换章 / 快速连翻无 stale staging 污染 active session
- [x] 不恢复 Dart approximate 分页生产路径
- [x] `flutter test test/features/reader/` 通过（119 passed, 36 skipped）

## 风险

| 风险 | 缓解 |
|------|------|
| 单 handle 与后台 paginate 冲突 | 用 `paginate_chapter` 无 handle API |
| STREAMER_CACHE LRU(4) 驱逐 | preview 用完即 pop 或短生命周期 key |
| 内存：同时持有两章 streamer | preview 只保留 descriptors + 1 页文本，不保留 full streamer |
| EPUB 大章 partial 2000 字不够换章首屏 | 换章 fast path 仍触发 expandToFull |

## 改动历史

| 日期 | 改动 |
|------|------|
| 2026-06-16 | 初始审计，发现存量代码已完成绝大部分 |
| 2026-06-16 | preloadNextChapterStaging 改用实参配置替代硬编码；增加 Timing 日志；触发 preloadGeneration notifier |
