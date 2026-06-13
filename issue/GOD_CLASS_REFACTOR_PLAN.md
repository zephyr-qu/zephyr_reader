# 上帝类拆分方案

> 基于 `issue/GOD_CLASS_AUDIT.md` | 2026-06-11

---

## 总览

| God Class | 当前行数 | 拆分后文件数 | 新增类 | API 兼容 |
|-----------|---------|------------|--------|---------|
| `ReaderViewModel` | 641 | 4 个 controller + 1 个 VM | 3 | **保持**（Phase 1 通过 getter 代理） |
| `ReaderRepository` | 705 | 3 个文件 | 2 | 部分破坏，调用方逐个迁移 |
| `BookshelfViewModel` | 485 | 2 个文件 | 1 | **保持** |

---

## 1. ReaderViewModel → 4 个 Controller + 1 个协调 VM

### 1.1 现状分析

当前 `ReaderViewModel` 直接管理 7 个职责领域，持有 16 个 signal、35+ 方法。
已委托给 `ChapterManager`（章节管理）和 `ReadingSessionManager`（计时），
但书签、批注、翻译、双语高亮仍由 VM 直接处理，含 FFI 调用和缓存。

调用方（23 处引用）：

| 文件 | 使用的方法/信号 | 变更影响 |
|------|----------------|---------|
| `reader_page.dart` | 几乎所有 signal 和方法 (~65 处访问) | 高 |
| `bookmark_manage_page.dart` | `bookmarks`, `loadBookmarks`, `deleteBookmark`, `jumpToBookmark` | 中 |
| `reader_page_actions.dart` | `selectedText`, `selectionStart/End`, `toastMessage`, `createBilingualHighlight`, `bilingualAlignment` | 高 |
| `reader_dictionary_panel.dart` | `vm` 作为参数传入 (3 处) | 中 |
| `reader_note_sidebar.dart` | `vm` 直接引用 | 低 |
| `reader_page_bindings.dart` | `vm.config.theme`, ChapterManager 委托信号 | 低 |

### 1.2 拆分策略：Phase 1（内部拆分，API 保持）

**不改变 ReaderViewModel 的外部 API（所有信号和方法路径不变）**，
但将实现拆分为 3 个内部 Controller + 1 个 Settings 信号群。

```
ReaderViewModel (协调层, ~150 行)
├── BookmarkController       (~80 行)  // 书签信号 + CRUD + 定位
├── AnnotationController     (~100 行) // 选中文本 + 高亮/批注 + 缓存
├── TranslationController    (~160 行) // 翻译 API + 双语对齐 + 双语高亮
├── ChapterManager           (已存在)  // 章节 + 分页 + 导航
├── ReadingSessionManager    (已存在)  // 计时 + 进度保存
└── ReaderConfig + 设置方法  (保留VM)  // 排版设置（setFontSize 等）
```

**关键设计决策**：

1. **Controller 不持有 VM 引用** — 通过构造注入 `ReaderConfig`、`ReaderRepository`、`ChapterManager` 等依赖，避免循环引用。
2. **跨 Controller 协调在 VM 层** — `initialize()`、`resetForNewBook()` 仍由 VM 编排。
3. **Signal 所有权归 Controller** — VM 通过 getter 暴露：

```dart
// reader_view_model.dart (拆分后)
class ReaderViewModel {
  late final BookmarkController _bookmarks;
  late final AnnotationController _annotations;
  late final TranslationController _translation;
  late final ChapterManager chapterManager;
  late final ReadingSessionManager sessionManager;

  // ====== 书签 getter ======
  AsyncSignal<List<Bookmark>> get bookmarks => _bookmarks.bookmarks;
  Future<void> loadBookmarks() => _bookmarks.loadBookmarks(bookId.value);
  Future<bool> addBookmark() => _bookmarks.addBookmark(/* params from chapter */);
  // ... 其余书签方法

  // ====== 批注 getter ======
  Signal<String> get selectedText => _annotations.selectedText;
  Future<void> saveHighlight(AppLocalizations l10n) => _annotations.saveHighlight(l10n, /* params */);
  // ... 其余批注方法

  // ====== 翻译 getter ======
  Future<void> translateChapter() => _translation.translateChapter(/* params */);
  // ...
}
```

### 1.3 各 Controller 详细设计

#### BookmarkController

```dart
// lib/features/reader/application/bookmark_controller.dart
class BookmarkController {
  final ReaderRepository _repo;

  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));
  late final ReadonlySignal<Map<String, Bookmark>> bookmarkIndex = computed(/*...*/);

  Future<void> loadBookmarks(String bookId) async { /* FFI: bookmark_api.listBookmarksByBook */ }
  Future<bool> addBookmark({required bookId, required chapterIndex, required charOffset}) async { /* FFI: bookmark_api.createBookmark */ }
  Future<bool> deleteBookmark(String bookmarkId) async { /* FFI: bookmark_api.deleteBookmark */ }
  bool hasBookmarkAtPosition(int chapterIndex, int charOffset);
  Bookmark? bookmarkAtPosition(int chapterIndex, int charOffset);
  Future<bool> toggleAtPosition({required bookId, required chapterIndex, required charOffset}) async;
}
```

**迁移影响**：`bookmark_manage_page.dart` 只需 `vm.bookmarks`、`vm.loadBookmarks()`、`vm.deleteBookmark()`、`vm.jumpToBookmark()` — getter 路径不变，**零代码改动**。

#### AnnotationController

```dart
// lib/features/reader/application/annotation_controller.dart
class AnnotationController {
  final ReaderRepository _repo;

  final selectedText = signal<String>('');
  final selectionStart = signal<int>(0);
  final selectionEnd = signal<int>(0);
  final highlights = asyncSignal<List<Note>>(AsyncState.data([]));
  final Map<int, List<Note>> _highlightsCache = {};

  void updateSelection(String text, int start, int end);
  void clearSelection();

  Future<void> loadHighlights({required String bookId, required int chapterIndex, bool forceRefresh = false});
  Future<void> saveHighlight({required String bookId, required int chapterIndex, required AppLocalizations l10n});
  Future<void> saveAnnotation({required String bookId, required int chapterIndex, required String content, required AppLocalizations l10n});
  Future<void> deleteNote(String noteId, AppLocalizations l10n);
  Future<void> updateNote(Note note, AppLocalizations l10n);
  void dispose();
}
```

**关键细节**：`deleteNote` 中调用 `deleteBilingualHighlightPair` — 这个 FFI 调用属于双语高亮，应通过 `TranslationController` 暴露。Controller 间的协调方法由 VM 层编排：

```dart
// 在 ReaderViewModel 中:
Future<void> deleteNote(String noteId, AppLocalizations l10n) async {
  await _translation.deleteBilingualPair(noteId: noteId);
  hapticFeedback(HapticType.heavy);
  await _annotations.loadHighlights(forceRefresh: true, /*...*/);
}
```

#### TranslationController

```dart
// lib/features/reader/application/translation_controller.dart
class TranslationController {
  final ReaderRepository _repo;
  final TranslationConfig _config;
  final TranslationService _service;
  final TranslationCache _cache = TranslationCache();
  CancelToken? _cancelToken;

  final bilingualAlignment = asyncSignal<BilingualAlignment?>(AsyncState.data(null));
  final translationContent = signal<String>('');

  bool get isConfigured => _config.isConfigured;

  Future<void> translateChapter({required String content, required int chapterIndex});
  Future<void> runBilingualAlignment({required String content, required String translation});
  void setTranslationContent(String content);
  void cancelTranslation();

  Future<void> createBilingualHighlight(/* 14 params */);
  Future<void> deleteBilingualPair({required String noteId});
  String translateErrorMessage(DioException e);
  void dispose();
}
```

**关键细节**：
- `translateChapter` 需要访问当前章节内容 → 由 VM 传入 `content` 参数，不直接依赖 ChapterManager
- `setReadingMode` 中的双语模式切换逻辑 → 保留在 VM，调用 `_translation.translateChapter()`
- `_translateErrorMessage` 是纯函数，移到 controller 或 utils

### 1.4 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `lib/features/reader/application/bookmark_controller.dart` | BookmarkController (~80 行) |
| 新建 | `lib/features/reader/application/annotation_controller.dart` | AnnotationController (~100 行) |
| 新建 | `lib/features/reader/application/translation_controller.dart` | TranslationController (~160 行) |
| 修改 | `lib/features/reader/application/reader_view_model.dart` | 从 641 行缩减到 ~150 行，仅保留编排逻辑 + getter 代理 |
| 修改 | `lib/di/service_locator.dart` | 注册 3 个新 Controller（如需要 DI）**
| 不改 | 所有 `*_page.dart`、`*_actions.dart` 等调用方 | getter 路径不变 |

> ** Controller 可设计为内部类（VM 直接 new，不通过 DI），因为它们的生命周期完全跟随 ReaderViewModel，且不需要被其他模块直接注入。

### 1.5 测试策略

- **现有测试** `reader_view_model_test.dart` — 拆分为 4 个测试文件，每个聚焦一个 Controller
- **新增测试**：每个 Controller 的独立单元测试
- **集成测试**：VM 编排测试（initialize → 各 Controller 状态一致性）

---

## 2. ReaderRepository → 3 个子模块

### 2.1 现状分析

当前 705 行，混合了：
- FFI 数据加载（章节内容、元数据）
- 3 种分页策略（Rust 全量、Rust 部分量、Dart 估算）
- 页面缓存管理（含 LRU-like 驱逐）
- 预加载与首屏优化

调用方（19 处引用）：

| 调用方 | 使用的方法 |
|--------|-----------|
| `ChapterManager` | `getChapters`, `loadChapterContent`, `loadChapterFirstSpine`, `paginateChapter`, `paginateChapterPartial`, `calculatePages`, `preloadChapter`, `preloadNextChapterFirstPage`, `loadReadingProgress`, `getPreloadedNextChapterContent`, `descriptors`, `currentPages`, `ensurePageWindow`, `warmPageCache`, `clearPreloadedNextChapter` |
| `ReaderViewModel` | （通过 ChapterManager 间接使用） |
| `reader_page.dart` | `getIt<ReaderRepository>()` 传给 `reader_content.dart` |
| `reader_content.dart` | `getPageContent`, `preloadGeneration` |
| `paginated_renderer.dart` | `repo` (传给 page builder) |
| `scroll_mode_renderer.dart` | `repo` |

### 2.2 拆分策略

```
ReaderRepository (Facade, ~120 行)
├── ChapterContentLoader    (~150 行)  // FFI: 章节内容 + 书籍元数据 + 富文本
├── PaginationEngine         (~220 行) // Rust 分页 + Dart 估算分页 + 页面缓存
└── (预加载逻辑并入 PaginationEngine 或保留在 Repo)
```

**关键设计决策**：

1. **ReaderRepository 保持为 Facade** — 外部调用方仍通过 `repo.xxx()` 访问，内部委托给子模块。彻底消除 API 破坏。
2. **PaginationEngine 无状态** — 不持有 `_pageCache`、`_descriptors` 等可变状态。状态保留在 Repository 中（Repository 作为缓存持有者是合理的），算法纯函数化。
3. **ChapterContentLoader 无状态** — 只负责 FFI 调用和 RichText 转换，不缓存。

### 2.3 各子模块设计

#### ChapterContentLoader

```dart
// lib/features/reader/data/chapter_content_loader.dart
class ChapterContentLoader {
  final RichTextConverter _converter = const RichTextConverter();

  Future<Book> getBook(String bookId);                    // ← 当前 _getBook
  Future<String> loadChapterContent(String bookId, int chapterId);  // FFI + EPUB/MD 富文本
  Future<String> loadChapterFirstSpine(String bookId, int chapterId);
  Future<List<Chapter>> getChapters(String bookId);
  Future<ReadingProgressData?> loadReadingProgress(String bookId);
}
```

#### PaginationEngine

```dart
// lib/features/reader/data/pagination_engine.dart
class PaginationEngine {
  /// Rust 全量分页（返回描述符列表）
  Future<int> paginateChapter({
    required String bookId, required int chapterIndex,
    required TypesetConfig config, required String filePath,
  });

  /// Rust 部分量分页（前 50k 字符）
  Future<int> paginateChapterPartial({/* same params + maxChars = 50000 */});

  /// Dart 估算分页（无需 FFI，毫秒级）
  List<PageInfo> paginateApproximate(
    String content, {
    required double fontSize, required double lineHeight,
    required double width, required double height, required double padding,
  });

  /// 根据字符偏移二分查找页码（对 descriptors）
  static int resolvePageIndex(List<PageDescriptor> descriptors, int charOffset);

  /// 根据字符偏移二分查找页码（对 PageInfo 列表）
  static int resolvePageIndexFromPageInfo(List<PageInfo> pages, int charOffset);
}
```

**注意**：二进制搜索 `resolvePageIndexForOffset` 和 `resolvePageIndexFromPageInfo` 目前在 `ChapterManager` 中，也应移到 PaginationEngine 作为静态方法。

### 2.4 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `lib/features/reader/data/chapter_content_loader.dart` | ChapterContentLoader (~150 行) |
| 新建 | `lib/features/reader/data/pagination_engine.dart` | PaginationEngine (~220 行) |
| 修改 | `lib/features/reader/data/repositories/rust_reader_repository.dart` | 缩减到 ~120 行，仅保留缓存状态 + 委托调用 |
| 修改 | `lib/features/reader/application/chapter_manager.dart` | 将 `resolvePageIndexForOffset` 调用改为 `PaginationEngine.resolvePageIndex` |

### 2.5 测试策略

- 现有 mock `ReaderRepository` 的测试 — **不受影响**（Repository 仍是 Facade）
- 新增 `chapter_content_loader_test.dart` — 验证 FFI 调用和 RichText 转换
- 新增 `pagination_engine_test.dart` — 验证 3 种分页策略和二分查找

---

## 3. BookshelfViewModel → 提取 BookImportService

### 3.1 现状分析

485 行。核心问题是 **文件 I/O 操作**（`scanFolder`、`importBook`、封面提取）混在 ViewModel 中。
`_Semaphore` 并发控制是一个完全不应该出现在 ViewModel 中的类。

调用方（15 处引用）：

| 文件 | 使用内容 |
|------|---------|
| `bookshelf_page.dart` | 几乎所有方法 (6 处) |
| `book_detail_page.dart` | 仅 `getIt<BookshelfViewModel>()` → 调用 `loadBooks` 使列表失效 |

### 3.2 拆分策略：最小改动

```
BookshelfViewModel (~370 行，-115)
└── BookImportService (新建，~130 行)
```

**只提取一个 Service**，因为其他职责（书籍 CRUD、筛选、排序、搜索）都是 ViewModel 的自然职责。

### 3.3 BookImportService 设计

```dart
// lib/features/bookshelf/application/book_import_service.dart
@lazySingleton
class BookImportService {
  static const int _scanConcurrency = 4;

  /// 导入单个书籍文件（解析 + 存入 DB + 提取封面）
  Future<bool> importBook(String filePath);

  /// 批量扫描文件夹，导入所有支持的书籍文件
  /// 返回 (successCount, failCount)
  Future<(int, int)> scanFolder(
    String folderPath, {
    void Function(int done, int total)? onProgress,
  });

  /// 重新提取书籍封面
  Future<bool> reExtractCover(String bookId, String filePath);

  // 内部
  Future<void> _extractCover(String bookId, String filePath);
}
```

**`_Semaphore` 类**：从 `bookshelf_view_model.dart` 末尾移除，移入 `book_import_service.dart`。

### 3.4 文件变更清单

| 操作 | 文件 | 说明 |
|------|------|------|
| 新建 | `lib/features/bookshelf/application/book_import_service.dart` | BookImportService + _Semaphore (~130 行) |
| 修改 | `lib/features/bookshelf/application/bookshelf_view_model.dart` | 删除 importBook/scanFolder/_extractCover/reExtractCover/_Semaphore，注入 BookImportService |
| 修改 | `lib/features/bookshelf/page/bookshelf_page.dart` | `_showImportDialog` / `_showScanDialog` 中调用 `bookImportService.importBook()` 替代 `vm.importBook()` |
| 修改 | `lib/di/service_locator.dart`（或 `app_module.dart`） | 注册 BookImportService |

### 3.5 API 变化

`bookshelf_page.dart` 中两个私有方法的改动：

```dart
// 之前：
Future<void> _showImportDialog(BuildContext context, BookshelfViewModel vm) async {
  // ...
  final ok = await vm.importBook(filePath);
  // ...
}

// 之后：
Future<void> _showImportDialog(BuildContext context, BookshelfViewModel vm) async {
  final importService = getIt<BookImportService>();
  // ...
  final ok = await importService.importBook(filePath);
  if (ok) await vm.loadBooks(); // ← 由 ViewModel 重新加载列表
  // ...
}
```

### 3.6 测试策略

- 现有 `bookshelf_view_model_test.dart` — 移除 I/O 相关测试，保持列表管理测试
- 新增 `book_import_service_test.dart` — 验证文件导入流程

---

## 4. 实施顺序

建议按以下顺序执行，每个阶段可独立提交：

```
Phase 1: BookshelfViewModel (+ BookImportService)     ← 最简单，风险最低，2 文件
Phase 2: ReaderRepository (+ ChapterContentLoader, PaginationEngine)  ← 中等，4 文件
Phase 3: ReaderViewModel (+ 3 Controllers)             ← 最复杂，5 文件

每个 Phase 完成后：
  1. dart analyze --fatal-infos 通过
  2. 相关单元测试通过
  3. 如有条件，E2E 冒烟测试
```

**Phase 3 进一步拆分为子步骤**：
- 3a: `AnnotationController` 提取（与翻译/书签解耦最少）
- 3b: `BookmarkController` 提取
- 3c: `TranslationController` 提取
- 3d: `ReaderViewModel` 瘦身完成

---

## 5. 风险与回退

| 风险 | 缓解 |
|------|------|
| Signal 订阅在 Controller 迁移后断开 | 每个 Controller 在构造时初始化自己的 signals，VM 通过 getter 暴露，不改变订阅路径 |
| `resetForNewBook` 遗漏重置某个 Controller 状态 | 各 Controller 提供 `dispose()`/`reset()` 方法，VM 统一调用 |
| FFI 调用移到 Controller 后，`ReaderRepository` 不再是唯一 FFI 入口 | 可接受 — Repository 模式允许 service 层直接调用 FFI；如果团队偏好统一入口，Controller 通过 Repository 调用 |
| 测试大量重写 | Phase 1 模式保证 API 不变 → 现有测试大部分原样通过 |

---

## 6. 附录：拆分后文件行数预估

| 文件 | 当前 | 拆分后 | 变化 |
|------|------|--------|------|
| `reader_view_model.dart` | 641 | ~150 | -491 |
| `bookmark_controller.dart` | — | ~80 | +80 |
| `annotation_controller.dart` | — | ~100 | +100 |
| `translation_controller.dart` | — | ~160 | +160 |
| `rust_reader_repository.dart` | 705 | ~120 | -585 |
| `chapter_content_loader.dart` | — | ~150 | +150 |
| `pagination_engine.dart` | — | ~220 | +220 |
| `bookshelf_view_model.dart` | 485 | ~370 | -115 |
| `book_import_service.dart` | — | ~130 | +130 |
| **净增行数** | — | — | **~89 行** (几乎持平) |
