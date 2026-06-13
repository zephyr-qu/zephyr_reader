# 上帝类审计报告

> 审计日期：2026-06-11 | 范围：`lib/` 下手写代码（排除 `frb_generated.*`、`*.freezed.dart`、`app_localizations*.dart`）

## 判断标准

上帝类判定：单一类承担 **≥3 个不相关职责领域** 或方法数超过合理阈值（ViewModel ≤15，Repository ≤12，Widget build 方法 ≤200 行）。

---

## 🔴 P0 — 明确上帝类

### 1. `ReaderViewModel` — 641 行 / 35+ 方法

**文件**: `lib/features/reader/application/reader_view_model.dart`

**承担的职责领域（7 个）**:

| # | 职责 | 证据 |
|---|------|------|
| 1 | 书签 CRUD + 位置查询 | `loadBookmarks`, `addBookmark`, `deleteBookmark`, `toggleBookmarkAtCurrentPosition`, `hasBookmarkAtCurrentPosition`, `currentBookmark` |
| 2 | 划词高亮/批注管理 | `loadHighlights`, `saveHighlight`, `saveAnnotation`, `deleteNote`, `updateNote`, `updateSelection`, `clearSelection` |
| 3 | 翻译 API 编排 | `translateChapter`, `_translateErrorMessage`, `_translateCancelToken` 管理 |
| 4 | 双语对齐 | `_runBilingualAlignment`, `setTranslationContent`, `bilingualAlignment`, `translationContent` |
| 5 | 双语跨语言高亮 | `createBilingualHighlight` (14 个参数) |
| 6 | 阅读排版设置 | `setFontSize`, `setLineHeight`, `setLetterSpacing`, `setParagraphSpacing`, `setPageMargin`, `setReadingMode`, `_debounceReloadChapter` |
| 7 | 章节/页面导航编排 | `initialize`, `loadChapter`, `loadPage`, `jumpToChapter`, `jumpToPosition`, `previousChapter`, `nextChapter`, `previousPage`, `nextPage`, `resetForNewBook` |

**问题**：自述 "Facade / 轻量协调层"，实际承载了阅读器的全部业务逻辑。书签、高亮、翻译、双语是 4 个独立功能模块，不应共用一个 ViewModel。

**重构方向**：
- `BookmarkViewModel` — 书签管理
- `AnnotationViewModel` — 高亮/批注管理  
- `TranslationViewModel` — 翻译编排（含双语）
- `ReaderViewModel` — 仅保留阅读核心（初始化、章节导航、排版设置）

---

### 2. `ReaderRepository` — 705 行 / 20+ 方法

**文件**: `lib/features/reader/data/repositories/rust_reader_repository.dart`

**承担的职责领域（5 个）**:

| # | 职责 | 证据 |
|---|------|------|
| 1 | 章节内容加载 | `loadChapterContent` (100+ 行，含 EPUB/MD 富文本转换) |
| 2 | 分页算法（3 种策略） | `paginateChapter`, `paginateChapterPartial`, `_paginateApproximate`, `calculatePages` |
| 3 | 页面缓存管理 | `_pageCache`, `_fetchPageSync`, `ensurePageWindow`, `_prefetchSurrounding`, `warmPageCache` |
| 4 | 预加载 | `preloadNextChapterFirstPage`, `preloadChapter`, `getPreloadedNextChapterContent` |
| 5 | 书籍元数据缓存 + 进度加载 | `_getBook`, `loadChapterFirstSpine`, `loadReadingProgress`, `getChapters` |

**问题**：一个 Repository 不应同时包含数据加载、3 种分页策略、缓存管理和预加载逻辑。违反单一职责原则。

**重构方向**：
- `ChapterLoader` — 章节内容加载 (FFI 调用)
- `PaginationEngine` — 分页算法（含 Rust/approximate 策略）
- `PageCacheManager` — 页面缓存 + 预加载
- `ReaderRepository` — 仅保留数据协调/聚合

---

### 3. `BookshelfViewModel` — 485 行 / 25+ 方法

**文件**: `lib/features/bookshelf/application/bookshelf_view_model.dart`

**承担的职责领域（6 个）**:

| # | 职责 | 证据 |
|---|------|------|
| 1 | 书籍 CRUD + 缓存 | `loadBooks`, `reloadBooks`, `getBookDetail`, `deleteBook`, `_safeAction` |
| 2 | 分类/状态筛选 | `selectCategory`, `selectStatus`, `updateBookCategories` |
| 3 | 搜索 | `startSearch`, `stopSearch`, `updateSearchKeyword`, `searchKeyword` |
| 4 | 排序 + 视图模式 | `defaultSortType`, `toggleViewMode`, `isListView` |
| 5 | 文件导入/扫描 | `importBook`, `scanFolder` (含 `_Semaphore` 并发控制) |
| 6 | 封面提取 | `_extractCover`, `reExtractCover` |

**问题**：ViewModel 不应包含文件扫描并发控制（`_Semaphore` 类定义在同文件）和封面提取逻辑。

**重构方向**：
- `BookImportService` — 文件导入/扫描/封面提取（新建 service 层）
- `BookshelfViewModel` — 仅保留列表管理、筛选、排序、搜索

---

## 🟡 P1 — 复杂性过高 / 文件级上帝类

### 4. `ReaderSettingsOverlay` — 935 行 / 单一 StatelessWidget

**文件**: `lib/features/reader/page/widgets/reader_settings_overlay.dart`

**问题**：一个 `StatelessWidget` 根据 `ReaderPanelType` 枚举渲染 4 种完全不同的设置面板（typesetting / display / more / tts）。935 行集中于一个文件、一个 build 方法的分支内。

**重构方向**：拆为 4 个独立 Widget：
- `TypesettingPanel`
- `DisplayPanel`
- `MorePanel`
- `TtsPanel`

---

### 5. `TranslationSettingsPage` — 633 行 / 含 8 个私有类
**问题**：一个文件包含 1 个公开 Page + 6 个私有 Widget 类 + 2 个 helper 函数。虽非单一类过胖，但文件级上帝类影响可维护性。
**文件**: `lib/features/reader/page/widgets/translation_settings_page.dart`


**重构方向**：拆分为独立文件：
- `translation_settings_page.dart` — 主页面
- `_provider_section.dart`
- `_api_section.dart`
- `_lang_section.dart`
- `_test_section.dart`
- `_select_tile.dart`
- `_input_tile.dart`

---

### 6. `ChapterManager` — 592 行 / `loadChapter` 方法 200+ 行

**文件**: `lib/features/reader/application/chapter_manager.dart`

**问题**：非传统上帝类（职责集中在章节管理），但 `loadChapter` 方法过于复杂：首屏加载 → 局部分页 → 全文分页 → 回退分页 → 搜索索引 → 预加载。200+ 行单一方法不可维护。此外还包含 FTS5 全文搜索索引（`_indexForSearch`）——这是独立功能，不应属于章节管理器职责。

**重构方向**：将 `loadChapter` 拆分为阶段化流程：
```dart
Future<void> loadChapter(int index) async {
  await _loadFirstScreen(index);    // 首屏速显
  await _loadPartialPagination();   // 局部分页
  await _loadFullPagination();      // 完整分页
  _scheduleSearchIndex();           // 异步搜索索引
  _schedulePreload();               // 异步预加载
}
```

---

## 🟢 P2 — 监控级（当前可接受，继续增长需拆分）

| 文件 | 行数 | 备注 |
|------|------|------|
| `reader_page.dart` | 594 | `build()` 492 行，含 TTS/词汇/inline 回调过多 |
| `bookshelf_page.dart` | 522 | `_showSettingsSheet` 85 行 + `_showBookActions` 70 行 |
| `reader_content.dart` | 538 | 作为路由组件复杂度可接受 |
| `tts_service.dart` | 328 | 聚焦 TTS，方法数合理 |
| `main_layout.dart` | 361 | 含导航栏 + Drawer + FAB，可接受 |

---

## 📊 统计总览

| 类别 | 数量 |
|------|------|
| P0 上帝类 | 3 (`ReaderViewModel`, `ReaderRepository`, `BookshelfViewModel`) |
| P1 高复杂度 | 3 (`ReaderSettingsOverlay`, `TranslationSettingsPage`, `ChapterManager`) |
| P2 监控级 | 5 |
| ViewModel 总数 | 17 |
| ViewModel 平均行数 | 137 |
| 超过 3x 均值 (≥400行) 的 VM | 2 (`ReaderViewModel` 641, `BookshelfViewModel` 485) |

---

## 附录：ViewModel 行数分布

```
reader_view_model         641 ████████████████████████████████████
bookshelf_view_model      485 ███████████████████████████
backup_view_model         182 ██████████
search_view_model         135 ████████
category_view_model       121 ███████
storage_sync_view_model   102 ██████
tts_settings_view_model    93 █████
vocabulary_view_model      78 ████
other_settings_view_model  74 ████
book_detail_view_model     72 ████
reading_stats_view_model   67 ███
learning_notes_view_model  67 ███
cache_manage_view_model    64 ███
theme_brightness_view_model 53 ██
reading_sessions_view_model 52 ██
book_search_view_model     45 ██
home_view_model            35 █
profile_view_model          28 █
```
