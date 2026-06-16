---
name: 跨章无缝翻页预加载
overview: 在 pageTurn 模式下，于当前章阅读时后台预建下一章 PaginationSession（descriptors + 首页 content），使 PageCurlWidget 跨章翻页不白屏、不依赖 firstSpine 纯文本占位。
todos:
  - id: audit-current-preload
    content: 梳理 preloadNextChapterFirstPage / preloadGeneration / PageCurl extendedTotal 现状与缺口
    status: completed
  - id: next-chapter-session-cache
    content: Dart 侧 NextChapterStaging（章 index + descriptors + 可选 handle 策略）
    status: completed
  - id: background-begin-paginate
    content: ChapterNavigator / orchestrator 钩子：当前章 stable 后 beginPaginate(下一章, maxChars=2000)
    status: completed
  - id: pagecurl-handoff
    content: reader_content pageTurn 跨章页使用预加载 descriptors + pageContent；onReachEnd 切换 session
    status: completed
  - id: race-generation
    content: generation / 换章 / configReload 时 invalidate 预加载
    status: completed
  - id: tests
    content: chapter_manager + reader_content pageTurn 集成测试
    status: completed
  - id: fix-hardcoded-config
    content: preloadNextChapterStaging 改用实际排版参数替代硬编码 400×600/16px
    status: completed
  - id: configreload-preload
    content: configReload 后重建 staging 预加载
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

由 `RustChapterContentRepository` 持有。

**invalidate 实际路径**（非 `disposePagination`）：
- 每次 `ChapterLoadOrchestrator.run()` 入口 → `clearNextChapterStaging()`
- 包含：换章、configReload、换书（通过 reset → loadChapter → run）
- `disposePagination()` 不清 staging

#### 2. 预加载实现（无 handle 的轻量 API）

利用 Rust 现有的 `paginate_chapter`（无 handle，仅写入 STREAMER_CACHE），Dart 侧在 `RustChapterContentRepository.preloadNextChapterStaging` 中：

- `paginateChapter(filePath, chapterIndex, config, maxChars=2000)` → `PaginateResult`
- `getPageContent(filePath, chapterIndex, configHash, 0)` → 首页文本
- 组装为 `NextChapterStaging` 缓存到 `_nextChapterStaging` 字段

预加载配置使用 **实际阅读排版参数**（fontSize/lineHeight/width/height/padding/devicePixelRatio/fontFamily），通过接口链从 `ChapterNavigator` 传入。

#### 3. 后台触发时机

| 触发点 | 行为 |
|--------|------|
| `_runFirstSpine` 完成后 | `preloadAdjacentFirstPages(centerIndex)` → `preloadNextChapterStaging(bookId, nextIdx, ...)` |
| `_runConfigReload` 完成后 | 同上（2026-06-16 修复前遗漏） |
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
  - 校验 `staging.chapterIndex == chapterId + 1`（防御性 matches 检查）
  - 命中 → 渲染 `staging.firstPageContent` + `staging.descriptors[0].startOffset`
  - 未命中 → fall through 到普通 `buildSinglePageContent`（pageIndex 越界时 `pageContent` 返回 null，显示空页）
- `onReachEnd` → `nextChapter()` → `loadChapter()`（normalLoad，走完全编排路径）
- staging 完成后通过 `preloadGeneration` notifier 触发 UI 重建

[`ReaderRenderDataSource`](../lib/features/reader/core/data/reader_render_data_source.dart) 已包含 `NextChapterStaging? get nextChapterStaging`。

#### 6. 接口链

- `ChapterContentRepository`（domain 接口）— `preloadNextChapterStaging(bookId, chapterIndex, {fontSize, lineHeight, width, height, padding, devicePixelRatio, fontFamily})`, `nextChapterStaging`, `clearNextChapterStaging`
- `ReaderRepositoryInterface`（domain 接口）— 同上
- `ReaderRepository`（实现）— 委托到 `_chapterContent`
- `RustChapterContentRepository`（实现）— 实际业务逻辑 + `_stagingGen` 防护

#### 7. 日志与可观测性

`preloadNextChapterStaging` 包含 `[Timing]` 日志：
- `preloadNextChapterStaging: ${ms}ms (chapter=$idx, isPartial=..., pages=N)`
- `preloadNextChapterStaging complete: ${ms}ms (staging ready for chapter=$idx)`

### 未实现

#### Phase 2 — handle promote

若 Phase 1 dispose+recreate 仍然慢，可考虑：
1. Rust `create_pagination_session` 支持 staging 专用 handle 池
2. 换章：`dispose(current)` + assign staging handle → `_handle`

当前不实现，待 profiling 证明需要后补。

### 已知缺口

| # | 缺口 | 影响 | 状态 |
|---|------|------|------|
| 1 | `matches()` 原本未使用 | 防御性校验缺失 | 已修复：`reader_content.dart` 加入 `staging.chapterIndex == chapterId + 1` |
| 2 | configReload 不触发预加载 | 改字体/边距后 staging 清空但未重建 | 已修复：`_runConfigReload` 末调用 `preloadAdjacentFirstPages` |
| 3 | 无 staging 时虚拟页显示空白 | 跨章动画瞬间可能空 | 设计可接受（nextChapter 后异步加载新内容），不处理 |
| 4 | 无 `_stagingGen` 竞态单元测试 | race 防护仅靠代码审查 | 功能测试覆盖触发路径，但无 time 竞态测试 |
| 5 | 双轨预加载并存（`preloadNextChapterFirstPage` + staging） | 两条预加载路径，维护面×2 | scroll/pagination 模式仍依赖 firstSpine 纯文本，pageTurn 用 staging，合情但需注意 |

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
| 2026-06-16 | `preloadNextChapterStaging` 改用实参配置替代硬编码；加 Timing 日志；触发 `preloadGeneration` notifier |
| 2026-06-16 | `_runConfigReload` 后补 `preloadAdjacentFirstPages` 调用（修复 config 变更后 staging 不重建） |
| 2026-06-16 | `reader_content.dart` 虚拟页增加 `staging.chapterIndex == chapterId + 1` 防御校验 |
