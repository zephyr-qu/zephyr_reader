import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../core/reader/reader_config.dart';
import '../data/repositories/rust_reader_repository.dart';
import '../domain/services/highlight_painter.dart';
import 'chapter_manager.dart';
import 'reading_session_manager.dart';

/// 阅读器视图模型 — Facade
///
/// 轻量协调层：持有各 Controller，代理信号访问，处理跨 Controller 的编排逻辑。
/// 所有书籍/章节状态和分页逻辑委托给 ChapterManager。
/// 所有阅读计时和进度保存委托给 ReadingSessionManager。
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  /// 阅读配置
  ReaderConfig get config => _config;

  // ==================== 快捷 getter（ChapterManager） ====================

  Signal<String> get bookId => chapterManager.bookId;
  Signal<int> get chapterIndex => chapterManager.chapterIndex;
  AsyncSignal<List<Chapter>> get chapters => chapterManager.chapters;
  AsyncSignal<String> get chapterContent => chapterManager.chapterContent;
  Signal<int> get totalPages => chapterManager.totalPages;
  Signal<int> get pageIndex => chapterManager.pageIndex;
  Signal<int> get currentCharOffset => chapterManager.currentCharOffset;
  Signal<int?> get pendingJumpCharOffset =>
      chapterManager.pendingJumpCharOffset;
  Signal<bool> get isLoading => chapterManager.isLoading;
  Signal<String?> get error => chapterManager.error;
  Signal<double> get pageWidth => chapterManager.pageWidth;
  Signal<double> get pageHeight => chapterManager.pageHeight;
  Signal<double> get devicePixelRatio => chapterManager.devicePixelRatio;
  Signal<ReadingMode> get readingMode => chapterManager.readingMode;
  Signal<int> get autoScrollTick => chapterManager.autoScrollTick;
  ReadonlySignal<String> get progressText => chapterManager.progressText;
  ReadonlySignal<String> get currentChapterTitle =>
      chapterManager.currentChapterTitle;

  /// 字体大小（double，供 bindings 消费）
  late final ReadonlySignal<double> fontSizeDouble = computed(
    () => _config.fontSize.value,
  );

  // ==================== 搜索 信号 ====================

  final showSearch = signal<bool>(false);
  final searchQuery = signal<String>('');
  final searchMatches = signal<int>(0);
  final searchCurrentIndex = signal<int>(0);
  final searchMatchParagraph = signal<int>(-1);

  // ==================== 书签 信号 ====================

  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  // ==================== 批注 信号 ====================

  final selectedText = signal<String>('');
  final selectionStart = signal<int>(0);
  final selectionEnd = signal<int>(0);
  final showSelectionToolbar = signal<bool>(false);
  final highlights = asyncSignal<List<Note>>(AsyncState.data([]));

  // ==================== 双语 信号 ====================

  final bilingualAlignment = asyncSignal<BilingualAlignment?>(
    AsyncState.data(null),
  );
  final translationContent = signal<String>('');

  // ==================== UI 面板状态 ====================

  final showCatalog = signal<bool>(false);
  final showBookmarks = signal<bool>(false);
  final showToolbar = signal<bool>(false);
  final showSettings = signal<bool>(false);
  final toastMessage = signal<String>('');

  // ==================== 定时器 ====================

  final List<void Function()> _disposers = [];

  /// 高亮/笔记缓存（按章节索引）。
  /// 切换回已访问章节时避免重复 API 调用。
  final Map<int, List<Note>> _highlightsCache = {};
  late final ChapterManager chapterManager;
  late final ReadingSessionManager sessionManager;

  ReaderViewModel(this._repo, this._config) {
    chapterManager = ChapterManager(_repo, _config);
    sessionManager = ReadingSessionManager(_repo, chapterManager);
  }

  // ==================== 编排方法 ====================

  /// 初始化阅读器，加载章节列表、恢复阅读进度、加载书签并开始计时。
  Future<void> initialize(
    String bookId, {
    int initialChapterId = 0,
    int initialPageIndex = 0,
  }) async {
    resetForNewBook();
    chapterManager.bookId.value = bookId;
    chapterManager.currentCharOffset.value = 0;

    isLoading.value = true;
    error.value = null;

    _disposers.add(
      effect(() {
        if (_config.autoScroll.value && sessionManager.isReading.value) {
          chapterManager.startAutoScroll();
        } else {
          chapterManager.stopAutoScroll();
        }
      }),
    );

    try {
      await chapterManager.loadChapters();
      await chapterManager.loadLastProgress();

      final chaptersList = chapters.value.value;
      if (chaptersList != null && chaptersList.isNotEmpty) {
        final restoredChapterIndex = chapterManager.chapterIndex.value;
        final restoredCharOffset = chapterManager.currentCharOffset.value;
        final targetChapterIndex = initialChapterId > 0
            ? initialChapterId
            : restoredChapterIndex;
        final targetCharOffset =
            initialChapterId > 0 && initialChapterId != restoredChapterIndex
            ? 0
            : restoredCharOffset;
        await chapterManager.loadChapter(
          targetChapterIndex,
          initialCharOffset: targetCharOffset,
          restartSession: false,
          onChapterLoaded: loadHighlights,
        );
      }

      await loadBookmarks();
      sessionManager.startReading();
      sessionManager.startAutoSave();
    } catch (e) {
      error.value = '加载失败：$e';
      Logging.error('ReaderViewModel.initialize error', exception: e);
    } finally {
      isLoading.value = false;
    }
  }

  // ==================== 章节导航（VM 包装） ====================

  /// 加载章节内容（包装 ChapterManager + 加载高亮）
  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    bool restartSession = true,
  }) async {
    await chapterManager.loadChapter(
      chapterIndex,
      initialCharOffset: initialCharOffset,
      restartSession: restartSession,
      onChapterLoaded: loadHighlights,
    );
  }

  /// 加载指定页（不阻塞进度保存）。
  Future<void> loadPage(int pageIndex) async {
    chapterManager.loadPage(pageIndex);
    unawaited(sessionManager.saveProgress());
  }

  /// 跳转到指定章节（包装 ChapterManager + 隐藏目录）
  Future<void> jumpToChapter(int chapterIndex) async {
    await chapterManager.jumpToChapter(chapterIndex);
    showCatalog.value = false;
  }

  /// 跳转到指定章节的字符偏移位置。
  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await chapterManager.jumpToPosition(chapterIndex, charOffset);
  }

  /// 切换到上一章。
  Future<void> previousChapter() => chapterManager.previousChapter();

  /// 切换到下一章。
  Future<void> nextChapter() => chapterManager.nextChapter();

  /// 翻到上一页。
  void previousPage() => chapterManager.previousPage();

  /// 翻到下一页。
  void nextPage() => chapterManager.nextPage();

  /// 更新当前阅读的字符偏移位置。
  void updateCurrentCharOffset(int charOffset) =>
      chapterManager.updateCurrentCharOffset(charOffset);

  /// 消费待处理的跳转偏移（跳转完成后清除标记）。
  void consumePendingJumpOffset() => chapterManager.consumePendingJumpOffset();

  /// 更新阅读器的字体。
  void updateFont(String fontFamily) => chapterManager.updateFont(fontFamily);

  // ==================== UI 面板切换 ====================

  /// 切换目录面板的显示状态。
  void toggleCatalog() {
    showCatalog.value = !showCatalog.value;
    showBookmarks.value = false;
  }

  /// 切换书签面板的显示状态。
  void toggleBookmarks() {
    showBookmarks.value = !showBookmarks.value;
    showCatalog.value = false;
  }

  /// 切换底部工具栏的显示状态。
  void toggleToolbar() => showToolbar.value = !showToolbar.value;

  /// 切换设置面板的显示状态（同时显示工具栏）。
  void toggleSettings() {
    showSettings.value = !showSettings.value;
    showToolbar.value = showSettings.value;
  }

  // ==================== 搜索 ====================

  /// 切换搜索面板的显示状态，关闭时重置搜索状态。
  void toggleSearch() {
    showSearch.value = !showSearch.value;
    if (!showSearch.value) {
      searchQuery.value = '';
      searchMatches.value = 0;
      searchCurrentIndex.value = 0;
      searchMatchParagraph.value = -1;
    }
  }

  /// 更新搜索查询、匹配数量和当前匹配项。
  void updateSearch(
    String query, {
    int matches = 0,
    int currentIndex = 0,
    int paragraphIndex = -1,
  }) {
    searchQuery.value = query;
    HighlightPainter.invalidateCache();
    searchMatches.value = matches;
    searchCurrentIndex.value = currentIndex.clamp(
      0,
      (matches - 1).clamp(0, 999999),
    );
    searchMatchParagraph.value = paragraphIndex;
  }

  /// 用户输入搜索查询时触发。
  ///
  /// 优先通过 FTS5 索引获取匹配数（异步），索引未就绪时降级为 `updateSearch` 占位。
  /// 匹配位置在 Rust 侧由 `search()` 返回，Dart 侧不再全文扫描。
  Future<void> onSearchChanged(String query) async {
    if (query.isEmpty) {
      updateSearch('', matches: 0, currentIndex: 0, paragraphIndex: -1);
      return;
    }
    try {
      final results = await search_api.search(
        bookId: bookId.value,
        query: query,
        limit: 1000,
      );
      final currentChapterMatches = results
          .where((r) => r.chapterIndex == chapterIndex.value)
          .toList();
      updateSearch(query, matches: currentChapterMatches.length);
    } catch (_) {
      // FTS5 索引未就绪时静默降级（匹配数显示为 0，下次输入重试）
      updateSearch(query, matches: 0);
    }
  }

  /// 跳转到下一个搜索匹配项。
  void nextSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value + 1) % searchMatches.value;
  }

  /// 跳转到上一个搜索匹配项。
  void prevSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value - 1 + searchMatches.value) %
        searchMatches.value;
  }

  // ==================== 书签 ====================

  /// 加载当前书籍的所有书签。
  Future<void> loadBookmarks() async {
    await bookmarks.loadAsync(
      () => _repo.getBookmarks(bookId.value),
      label: 'loadBookmarks',
    );
  }

  /// 在当前阅读位置添加书签。
  Future<bool> addBookmark() async {
    try {
      await _repo.addBookmark(
        bookId.value,
        chapterIndex.value,
        currentCharOffset.value,
      );
      await loadBookmarks();
      return true;
    } catch (e) {
      Logging.error('addBookmark error', exception: e);
      return false;
    }
  }

  /// 删除指定书签。
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      final success = await _repo.deleteBookmark(bookmarkId);
      if (success) await loadBookmarks();
      return success;
    } catch (e) {
      Logging.error('deleteBookmark error', exception: e);
      return false;
    }
  }

  /// 跳转到指定书签位置并关闭书签面板。
  Future<void> jumpToBookmark(Bookmark bookmark) async {
    await jumpToPosition(bookmark.chapterIndex, bookmark.charOffset.toInt());
    showBookmarks.value = false;
  }

  /// 当前阅读位置是否存在书签。
  bool get hasBookmarkAtCurrentPosition {
    final currentBookmarks = bookmarks.value.value ?? [];
    return currentBookmarks.any(
      (b) =>
          b.chapterIndex == chapterIndex.value &&
          b.charOffset.toInt() == currentCharOffset.value,
    );
  }

  /// 获取当前阅读位置的书签（如果存在）。
  Bookmark? get currentBookmark {
    final currentBookmarks = bookmarks.value.value ?? [];
    try {
      return currentBookmarks.firstWhere(
        (b) =>
            b.chapterIndex == chapterIndex.value &&
            b.charOffset.toInt() == currentCharOffset.value,
      );
    } catch (_) {
      return null;
    }
  }

  /// 切换当前阅读位置的书签状态（添加/删除）。
  Future<bool> toggleBookmarkAtCurrentPosition() async {
    final existing = currentBookmark;
    if (existing != null) {
      return await deleteBookmark(existing.id);
    } else {
      return await addBookmark();
    }
  }

  // ==================== 划词批注 ====================

  /// 加载当前章节的全部高亮和笔记。
  ///
  /// [forceRefresh] 为 `true` 时绕过缓存，强制从 API 重新获取。
  Future<void> loadHighlights({bool forceRefresh = false}) async {
    final idx = chapterIndex.value;
    if (!forceRefresh) {
      final cached = _highlightsCache[idx];
      if (cached != null) {
        highlights.value = AsyncState.data(cached);
        return;
      }
    }
    try {
      final notes = await note_api.listNotesInChapter(
        bookId: bookId.value,
        chapterIndex: idx,
      );
      _highlightsCache[idx] = notes;
      highlights.value = AsyncState.data(notes);
    } catch (_) {
      highlights.value = AsyncState.data([]);
    }
    HighlightPainter.invalidateCache();
  }

  /// 更新当前选中的文本范围和内容。
  void updateSelection(String text, int start, int end) {
    selectedText.value = text;
    selectionStart.value = start;
    selectionEnd.value = end;
    showSelectionToolbar.value = text.isNotEmpty;
  }

  /// 清除当前选中文本并隐藏工具栏。
  void clearSelection() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    showSelectionToolbar.value = false;
  }

  /// 保存当前选中的文本为高亮。
  Future<void> saveHighlight() async {
    if (selectedText.value.isEmpty) return;
    try {
      await note_api.createHighlight(
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        charOffset: selectionStart.value,
        length: selectionEnd.value - selectionStart.value,
        selectedText: selectedText.value,
        color: 0xFFFFEB3B,
      );
      await loadHighlights(forceRefresh: true);
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存高亮失败';
    }
  }

  /// 保存当前选中的文本为笔记。
  Future<void> saveAnnotation(String annotationContent) async {
    if (selectedText.value.isEmpty || annotationContent.isEmpty) return;
    try {
      await note_api.createAnnotation(
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        charOffset: selectionStart.value,
        content: annotationContent,
        selectedText: selectedText.value,
      );
      await loadHighlights(forceRefresh: true);
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存笔记失败';
    }
  }

  /// 删除指定笔记或高亮。
  Future<void> deleteNote(String noteId) async {
    try {
      await note_api.deleteNote(noteId: noteId);
      hapticFeedback(HapticType.heavy);
      await loadHighlights(forceRefresh: true);
    } catch (e) {
      toastMessage.value = '删除失败';
    }
  }

  /// 更新笔记内容。
  Future<void> updateNote(Note note) async {
    try {
      await note_api.upsertNote(note: note);
      await loadHighlights(forceRefresh: true);
    } catch (e) {
      toastMessage.value = '更新笔记失败';
    }
  }

  // ==================== 设置变更 ====================

  /// 设置阅读器字体大小并重绘当前章节。
  Future<void> setFontSize(double size) async {
    _config.fontSize.value = size;
    await chapterManager.loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
      onChapterLoaded: loadHighlights,
    );
  }

  /// 设置阅读器行高并重绘当前章节。
  Future<void> setLineHeight(double height) async {
    _config.lineHeight.value = height;
    await chapterManager.loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
      onChapterLoaded: loadHighlights,
    );
  }

  /// 设置阅读模式（分页/滚动/双语），双语模式下自动触发对齐。
  void setReadingMode(ReadingMode mode) {
    readingMode.value = mode;
    if (mode == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  /// 设置翻译内容，双语模式下自动触发对齐。
  void setTranslationContent(String content) {
    translationContent.value = content;
    if (readingMode.value == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  /// 运行双语对齐（将中文内容与英文翻译逐段对齐）。
  Future<void> _runBilingualAlignment() async {
    final content = chapterContent.value.value ?? '';
    final translation = translationContent.value;
    if (translation.isEmpty) return;
    await bilingualAlignment.loadAsync(
      () => alignBilingualContent(
        chineseContent: content,
        englishContent: translation,
        minSimilarity: 0.5,
      ),
      label: '双语对齐',
    );
  }

  // ==================== 双语高亮 ====================

  /// 创建双语对照高亮（同时高亮原文和译文中对应的文本）。
  Future<void> createBilingualHighlight({
    required String sourceBookId,
    required int sourceChapterIndex,
    required int sourceCharOffset,
    required int sourceLength,
    required String sourceSelectedText,
    required String sourceLanguage,
    required String targetBookId,
    required int targetChapterIndex,
    required int targetCharOffset,
    required int targetLength,
    required String targetSelectedText,
    required String targetLanguage,
    int highlightColor = 0xFFE91E63,
  }) async {
    try {
      await createBilingualHighlightPair(
        params: BilingualHighlightParams(
          sourceBookId: sourceBookId,
          sourceChapterIndex: sourceChapterIndex,
          sourceCharOffset: sourceCharOffset,
          sourceLength: sourceLength,
          sourceSelectedText: sourceSelectedText,
          sourceLanguage: sourceLanguage,
          targetBookId: targetBookId,
          targetChapterIndex: targetChapterIndex,
          targetCharOffset: targetCharOffset,
          targetLength: targetLength,
          targetSelectedText: targetSelectedText,
          targetLanguage: targetLanguage,
          highlightColor: highlightColor,
        ),
      );
    } catch (e, stack) {
      Logging.error(
        'ReaderViewModel.createBilingualHighlight',
        exception: e,
        stackTrace: stack,
      );
      toastMessage.value = '双语高亮创建失败';
    }
  }

  // ==================== 重置 ====================

  /// 重置阅读器状态，清理定时器和信号，为切换书籍做准备。
  void resetForNewBook() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();

    chapterManager.reset();
    sessionManager.reset();

    toastMessage.value = '';
    showCatalog.value = false;
    showBookmarks.value = false;
    showToolbar.value = false;
    showSettings.value = false;
    showSearch.value = false;
    searchQuery.value = '';
    searchMatches.value = 0;
    searchCurrentIndex.value = 0;
    searchMatchParagraph.value = -1;
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    _highlightsCache.clear();
    showSelectionToolbar.value = false;
    highlights.value = AsyncState.data([]);
  }
}
