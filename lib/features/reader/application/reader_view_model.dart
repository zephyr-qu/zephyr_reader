import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../core/reader/reader_config.dart';
import '../data/repositories/rust_reader_repository.dart';
import 'annotation_controller.dart';
import 'bilingual_controller.dart';
import 'bookmark_controller.dart';
import 'chapter_manager.dart';
import 'reading_session_manager.dart';
import 'reader_search_controller.dart';

/// 阅读器视图模型 — Facade
///
/// 轻量协调层：持有各 Controller，代理信号访问，处理跨 Controller 的编排逻辑。
/// 所有书籍/章节状态和分页逻辑委托给 ChapterManager。
/// 所有阅读计时和进度保存委托给 ReadingSessionManager。
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  final BookmarkController _bookmarkController;
  final ReaderSearchController _searchController;
  final AnnotationController _annotationController;
  final BilingualController _bilingualController;

  /// 阅读配置（含翻页布局等）
  ReaderConfig get config => _config;

  // ==================== 快捷 getter 代理（ChapterManager） ====================

  Signal<String> get bookId => chapterManager.bookId;
  Signal<int> get chapterIndex => chapterManager.chapterIndex;
  AsyncSignal<List<Chapter>> get chapters => chapterManager.chapters;
  AsyncSignal<String> get chapterContent => chapterManager.chapterContent;
  Signal<int> get totalPages => chapterManager.totalPages;
  Signal<int> get pageIndex => chapterManager.pageIndex;
  Signal<int> get currentCharOffset => chapterManager.currentCharOffset;
  Signal<int?> get pendingJumpCharOffset => chapterManager.pendingJumpCharOffset;
  Signal<bool> get isLoading => chapterManager.isLoading;
  Signal<String?> get error => chapterManager.error;
  Signal<double> get pageWidth => chapterManager.pageWidth;
  Signal<double> get pageHeight => chapterManager.pageHeight;
  Signal<double> get devicePixelRatio => chapterManager.devicePixelRatio;
  Signal<ReadingMode> get readingMode => chapterManager.readingMode;
  Signal<int> get autoScrollTick => chapterManager.autoScrollTick;
  ReadonlySignal<String> get progressText => chapterManager.progressText;
  ReadonlySignal<String> get currentChapterTitle => chapterManager.currentChapterTitle;

  /// 字体大小（double，供 bindings 消费）
  late final ReadonlySignal<double> fontSizeDouble =
      computed(() => _config.fontSize.value);

  // ==================== 快捷 getter 代理（Controller） ====================

  AsyncSignal<List<Bookmark>> get bookmarks => _bookmarkController.bookmarks;
  Signal<bool> get showSearch => _searchController.showSearch;
  Signal<String> get searchQuery => _searchController.searchQuery;
  Signal<int> get searchMatches => _searchController.searchMatches;
  Signal<int> get searchCurrentIndex => _searchController.searchCurrentIndex;
  Signal<int> get searchMatchParagraph => _searchController.searchMatchParagraph;
  Signal<String> get selectedText => _annotationController.selectedText;
  Signal<int> get selectionStart => _annotationController.selectionStart;
  Signal<int> get selectionEnd => _annotationController.selectionEnd;
  Signal<bool> get showSelectionToolbar => _annotationController.showSelectionToolbar;
  Signal<List<Note>> get highlights => _annotationController.highlights;
  AsyncSignal<BilingualAlignment?> get bilingualAlignment => _bilingualController.bilingualAlignment;
  Signal<String> get translationContent => _bilingualController.translationContent;

  // ==================== UI 面板状态 ====================

  final showCatalog = signal<bool>(false);
  final showBookmarks = signal<bool>(false);
  final showToolbar = signal<bool>(false);
  final showSettings = signal<bool>(false);
  final toastMessage = signal<String>('');

  // ==================== 定时器 ====================

  final List<void Function()> _disposers = [];

  late final ChapterManager chapterManager;
  late final ReadingSessionManager sessionManager;

  ReaderViewModel(
    this._repo,
    this._config,
    this._bookmarkController,
    this._searchController,
    this._annotationController,
    this._bilingualController,
  ) {
    chapterManager = ChapterManager(_repo, _config);
    sessionManager = ReadingSessionManager(_repo, chapterManager);
    // 监听自动滚动设置
    _disposers.add(
      effect(() {
        if (_config.autoScroll.value && sessionManager.isReading.value) {
          chapterManager.startAutoScroll();
        } else {
          chapterManager.stopAutoScroll();
        }
      }),
    );
  }

  // ==================== 编排方法 ====================

  /// 初始化阅读器
  Future<void> initialize(
    String bookId, {
    int initialChapterId = 0,
    int initialPageIndex = 0,
  }) async {
    if (this.bookId.value == bookId &&
        chapters.value.value?.isNotEmpty == true) {
      return;
    }
    chapterManager.bookId.value = bookId;
    chapterManager.currentCharOffset.value = 0;

    isLoading.value = true;
    error.value = null;

    try {
      await chapterManager.loadChapters();
      await chapterManager.loadLastProgress();

      final chaptersList = chapters.value.value;
      if (chaptersList != null && chaptersList.isNotEmpty) {
        final restoredChapterIndex = chapterManager.chapterIndex.value;
        final restoredCharOffset = chapterManager.currentCharOffset.value;
        final targetChapterIndex =
            initialChapterId > 0 ? initialChapterId : restoredChapterIndex;
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

      await _bookmarkController.loadBookmarks(bookId);
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

  /// 加载指定页（包装 ChapterManager + 保存进度）
  Future<void> loadPage(int pageIndex) async {
    chapterManager.loadPage(pageIndex);
    await sessionManager.saveProgress();
  }

  /// 跳转到指定章节（包装 ChapterManager + 隐藏目录）
  Future<void> jumpToChapter(int chapterIndex) async {
    await chapterManager.jumpToChapter(chapterIndex);
    showCatalog.value = false;
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await chapterManager.jumpToPosition(chapterIndex, charOffset);
  }

  Future<void> previousChapter() => chapterManager.previousChapter();
  Future<void> nextChapter() => chapterManager.nextChapter();
  void previousPage() => chapterManager.previousPage();
  void nextPage() => chapterManager.nextPage();
  void updateCurrentCharOffset(int charOffset) =>
      chapterManager.updateCurrentCharOffset(charOffset);
  void consumePendingJumpOffset() => chapterManager.consumePendingJumpOffset();
  void updateFont(String fontFamily) => chapterManager.updateFont(fontFamily);

  // ==================== UI 面板切换 ====================

  void toggleCatalog() {
    showCatalog.value = !showCatalog.value;
    showBookmarks.value = false;
  }

  void toggleBookmarks() {
    showBookmarks.value = !showBookmarks.value;
    showCatalog.value = false;
  }

  void toggleToolbar() => showToolbar.value = !showToolbar.value;

  void toggleSettings() {
    showSettings.value = !showSettings.value;
    showToolbar.value = showSettings.value;
  }

  // ==================== 搜索（委托给 SearchController） ====================

  void toggleSearch() => _searchController.toggleSearch();
  void updateSearch(
    String query, {
    int matches = 0,
    int currentIndex = 0,
    int paragraphIndex = -1,
  }) => _searchController.updateSearch(
    query,
    matches: matches,
    currentIndex: currentIndex,
    paragraphIndex: paragraphIndex,
  );
  void nextSearchMatch() => _searchController.nextSearchMatch();
  void prevSearchMatch() => _searchController.prevSearchMatch();

  // ==================== 书签（委托给 BookmarkController） ====================

  Future<void> loadBookmarks() async {
    await _bookmarkController.loadBookmarks(bookId.value);
  }

  Future<bool> addBookmark() async {
    return await _bookmarkController.addBookmark(
      bookId.value,
      chapterIndex.value,
      currentCharOffset.value,
    );
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    return await _bookmarkController.deleteBookmark(bookmarkId, bookId.value);
  }

  Future<void> jumpToBookmark(Bookmark bookmark) async {
    await jumpToPosition(bookmark.chapterIndex, bookmark.charOffset.toInt());
    showBookmarks.value = false;
  }

  bool get hasBookmarkAtCurrentPosition {
    final currentBookmarks = bookmarks.value.value ?? [];
    return currentBookmarks.any(
      (b) =>
          b.chapterIndex == chapterIndex.value &&
          b.charOffset.toInt() == currentCharOffset.value,
    );
  }

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

  Future<bool> toggleBookmarkAtCurrentPosition() async {
    final existing = currentBookmark;
    if (existing != null) {
      return await deleteBookmark(existing.id);
    } else {
      return await addBookmark();
    }
  }

  // ==================== 划词批注（委托给 AnnotationController） ====================

  Future<void> loadHighlights() async {
    await _annotationController.loadHighlights(
      bookId.value,
      chapterIndex.value,
    );
  }

  void updateSelection(String text, int start, int end) =>
      _annotationController.updateSelection(text, start, end);

  void clearSelection() => _annotationController.clearSelection();

  Future<void> saveHighlight() async {
    if (_annotationController.selectedText.value.isEmpty) return;
    try {
      await _annotationController.createHighlight(
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        selectionStart: _annotationController.selectionStart.value,
        selectionEnd: _annotationController.selectionEnd.value,
        selectedText: _annotationController.selectedText.value,
      );
      hapticFeedback(HapticType.medium);
      await loadHighlights();
      _annotationController.clearSelection();
    } catch (e) {
      toastMessage.value = '保存高亮失败';
    }
  }

  Future<void> saveAnnotation(String annotationContent) async {
    if (_annotationController.selectedText.value.isEmpty ||
        annotationContent.isEmpty) {
      return;
    }
    try {
      await _annotationController.createAnnotation(
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        selectionStart: _annotationController.selectionStart.value,
        selectionEnd: _annotationController.selectionEnd.value,
        selectedText: _annotationController.selectedText.value,
        annotationContent: annotationContent,
      );
      await loadHighlights();
      _annotationController.clearSelection();
    } catch (e) {
      toastMessage.value = '保存笔记失败';
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await _annotationController.deleteNote(noteId);
      hapticFeedback(HapticType.heavy);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '删除失败';
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await _annotationController.updateNote(note);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '更新笔记失败';
    }
  }

  // ==================== 设置变更 ====================

  Future<void> setFontSize(double size) async {
    _config.fontSize.value = size;
    await chapterManager.loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
      onChapterLoaded: loadHighlights,
    );
  }

  Future<void> setLineHeight(double height) async {
    _config.lineHeight.value = height;
    await chapterManager.loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
      onChapterLoaded: loadHighlights,
    );
  }

  void setReadingMode(ReadingMode mode) {
    readingMode.value = mode;
    if (mode == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  void setTranslationContent(String content) {
    _bilingualController.translationContent.value = content;
    if (readingMode.value == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  Future<void> _runBilingualAlignment() async {
    final content = chapterContent.value.value ?? '';
    final translation = _bilingualController.translationContent.value;
    await _bilingualController.runAlignment(content, translation);
  }

  // ==================== 双语高亮 ====================

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

  void resetForNewBook() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();

    chapterManager.reset();
    sessionManager.reset();
    _bookmarkController.dispose();
    _searchController.dispose();
    _annotationController.dispose();
    _bilingualController.dispose();

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
    showSelectionToolbar.value = false;
    highlights.value = [];
  }
}
