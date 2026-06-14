# ReaderViewModel 瘦身计划

> 状态: 待执行 | 优先级: 中 | 预估工时: 1h

## 目标

将 `ReaderViewModel` 从 415 行缩减到 ~300 行，删除纯转发层样板代码，保留真正的编排逻辑。

## 当前结构分析

| 类别 | 行数 | 处理方式 |
|------|------|---------|
| 30 个 signal/getter 转发 | ~50 | 删除，消费方直接访问 controller |
| 10 个纯转发导航方法 | ~35 | 删除，消费方直接访问 chapterManager |
| saveHighlight / saveAnnotation 等薄 wrapper | ~30 | 删除，消费方调用 controller + 自行 toast |
| 构造函数（5 个 Controller 连线） | ~25 | 保留 |
| initialize() 编排 | ~50 | 保留 |
| resetForNewBook() 编排 | ~15 | 保留 |
| settings 方法 + \_debounceReloadChapter | ~50 | 保留 |
| createBilingualHighlight | ~45 | 保留 |
| toggleBookmarkAtCurrentPosition | ~10 | 保留 |
| deleteNote（跨 Controller） | ~10 | 保留 |
| toastMessage 信号 | ~5 | 保留 |

## 具体改动

### 1. ReaderViewModel 本身

**公开 Controller 字段代替 30 个 getter:**

```diff
- Signal<String> get bookId => chapterManager.bookId;
- Signal<int> get chapterIndex => chapterManager.chapterIndex;
- // ... 28 more getters

+ // 直接公开，消费方用 vm.chapterManager.bookId
+ late final ChapterManager chapterManager;
+ late final ReadingSessionManager sessionManager;
+ late final BookmarkController bookmarks;       // 原 _bookmarks
+ late final AnnotationController annotations;    // 原 _annotations
+ late final TranslationController translation;   // 原 _translation
```

**删除纯转发导航方法:**

```diff
- Future<void> previousChapter() => chapterManager.previousChapter();
- Future<void> nextChapter() => chapterManager.nextChapter();
- Future<void> previousPage() => chapterManager.previousPage();
- Future<void> nextPage() => chapterManager.nextPage();
- Future<void> loadPage(int pageIndex) { ... }
- Future<void> jumpToChapter(int chapterIndex) { ... }
- Future<void> jumpToPosition(int chapterIndex, int charOffset) { ... }
- void updateCurrentCharOffset(int charOffset) => ...
- void consumePendingJumpOffset() => ...
- void updateFont(String fontFamily) => ...
```

**删除薄 wrapper（保留 deleteNote, toggleBookmark 因为跨 Controller）:**

```diff
- Future<void> saveHighlight(AppLocalizations l10n) async { ... }
- Future<void> saveAnnotation(String content, AppLocalizations l10n) async { ... }
- Future<void> updateNote(Note note, AppLocalizations l10n) async { ... }
- Future<void> loadHighlights({bool forceRefresh = false}) => ...
- void updateSelection(String text, int start, int end) => ...
- void clearSelection() => ...
- Future<void> loadBookmarks() => ...
- Future<bool> addBookmark() => ...
- Future<bool> deleteBookmark(String id) => ...
```

**保留的方法:**

```dart
// 构造函数 — 连线逻辑
ReaderViewModel(this._repo, this._config, ...);

// 编排
Future<void> initialize(String bookId, ...);
Future<void> resetForNewBook();
Future<void> loadChapter(int chapterIndex, ...);

// settings + debounce
void setFontSize(double size);
void setLineHeight(double height);
void setLetterSpacing(double value);
void setParagraphSpacing(double value);
void setPageMargin(double value);
void setReadingMode(ReadingMode mode);

// 跨 Controller
Future<void> toggleBookmarkAtCurrentPosition();
Future<void> deleteNote(String noteId, AppLocalizations l10n);
Future<void> createBilingualHighlight({...});

// 翻译
void setTranslationContent(String content);
Future<void> translateChapter();

// toast 信号
final toastMessage = signal<String>('');
```

### 2. 消费方适配

#### reader_page.dart（改动最大）

```diff
- vm.bookId                      → vm.chapterManager.bookId
- vm.chapterIndex                → vm.chapterManager.chapterIndex
- vm.chapters                    → vm.chapterManager.chapters
- vm.chapterContent              → vm.chapterManager.chapterContent
- vm.totalPages                  → vm.chapterManager.totalPages
- vm.pageIndex                   → vm.chapterManager.pageIndex
- vm.currentCharOffset           → vm.chapterManager.currentCharOffset
- vm.isLoading                   → vm.chapterManager.isLoading
- vm.error                       → vm.chapterManager.error
- vm.previousPage()              → vm.chapterManager.previousPage()
- vm.nextPage()                  → vm.chapterManager.nextPage()
- vm.previousChapter()           → vm.chapterManager.previousChapter()
- vm.nextChapter()               → vm.chapterManager.nextChapter()
- vm.loadPage(n)                 → vm.chapterManager.loadPage(n)
- vm.jumpToChapter(n)            → vm.chapterManager.jumpToChapter(n)
- vm.updateCurrentCharOffset(n)  → vm.chapterManager.updateCurrentCharOffset(n)
- vm.bookmarks                   → vm.bookmarks.bookmarks
- vm.selectedText                → vm.annotations.selectedText
- vm.highlights                  → vm.annotations.highlights
- vm.isTranslationConfigured     → vm.translation.isConfigured
- vm.bilingualAlignment          → vm.translation.bilingualAlignment

// 薄 wrapper 改为直接调用
- vm.saveHighlight(l10n)         → try { await vm.annotations.saveHighlight(); } catch (_) { toast = l10n.saveHighlightFailed; }
- vm.saveAnnotation(c, l10n)      → try { await vm.annotations.saveAnnotation(c); } catch (_) { toast = l10n.saveAnnotationFailed; }
```

#### reader_page_bindings.dart

两个 hook 的参数改为接收具体 Controller 而非整个 VM:

```diff
- ReaderPageBindings useReaderBindings(ReaderViewModel vm) {
+ ReaderPageBindings useReaderBindings(ChapterManager cm, ReaderConfig config, BookmarkController bm) {

- ReaderPageBindings useReaderContentBindings(ReaderViewModel vm) {
+ ReaderPageBindings useReaderContentBindings(ChapterManager cm, ReaderConfig config) {
```

#### bookmark_manage_page.dart

```diff
- final vm = useMemoized(() => getIt<ReaderViewModel>());
+ final vm = useMemoized(() => getIt<ReaderViewModel>());

- vm.bookmarks  → vm.bookmarks.bookmarks
- vm.addBookmark() → vm.bookmarks.addBookmark()
- vm.deleteBookmark(id) → vm.bookmarks.deleteBookmark(id)
- vm.jumpToBookmark(b) → vm.jumpToPosition(b.chapterIndex, b.charOffset.toInt())
  // jumpToBookmark 内部逻辑内联到调用点
```

#### reader_page_actions.dart

函数签名改为接收具体 Controller:

```diff
- void _lookupWord(BuildContext context, ReaderViewModel vm, ...) {
+ void _lookupWord(BuildContext context, ChapterManager cm, AnnotationController ac, ...) {

- vm.selectedText.value → ac.selectedText.value
```

#### reader_dictionary_panel.dart

```diff
- void showDictionaryPanel(BuildContext context, ReaderViewModel vm, String text) {
+ void showDictionaryPanel(BuildContext context, ChapterManager cm, ReaderConfig config, String text) {

- vm.chapterContent.value.value → cm.chapterContent.value.value
- vm.config → config
```

#### reader_note_sidebar.dart

```diff
- final ReaderViewModel vm;
+ final ChapterManager chapterManager;
+ final AnnotationController annotations;

  // 构造参数拆分
```

## 执行步骤

1. **修改 ReaderViewModel**: 删除转发 getter/方法，公开 controller 字段
2. **修改 reader_page_bindings.dart**: 适配两个 hook 参数
3. **修改 reader_page.dart**: 最大的调用点适配
4. **修改 reader_page_actions.dart**: 参数改为 controller
5. **修改 reader_dictionary_panel.dart**: 参数改为 controller
6. **修改 reader_note_sidebar.dart**: 构造参数拆分
7. **修改 bookmark_manage_page.dart**: 调用点适配
8. **运行测试**: `dart analyze --fatal-infos` + 相关 widget 测试

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| 6 文件同步改动大 | 机械替换，无逻辑变更 |
| binding hook 参数列表变长 | 接受；参数变多是真实依赖的可视化 |
| `_annotations` 暴露为 public | 接口已是干净的信号/方法，无额外风险 |
| `jumpToBookmark` 逻辑内联 | 只有 2 处调用，内联 2 行 |

## 预期收益

- ReaderViewModel: 415 → ~300 行（-115 行）
- 消除 "打电话叫人打电话" 转发模式
- 每个信号只声明一次，不再在 VM 里重复声明
- Controller 依赖关系更透明
