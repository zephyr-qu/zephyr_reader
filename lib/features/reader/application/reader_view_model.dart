import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
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
  final highlights = signal<List<Note>>([]);

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

  late final ChapterManager chapterManager;
  late final ReadingSessionManager sessionManager;

  ReaderViewModel(this._repo, this._config) {
    chapterManager = ChapterManager(_repo, _config);
    sessionManager = ReadingSessionManager(_repo, chapterManager);
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

  void toggleSearch() {
    showSearch.value = !showSearch.value;
    if (!showSearch.value) {
      searchQuery.value = '';
      searchMatches.value = 0;
      searchCurrentIndex.value = 0;
      searchMatchParagraph.value = -1;
    }
  }

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

  void nextSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value + 1) % searchMatches.value;
  }

  void prevSearchMatch() {
    if (searchMatches.value <= 0) return;
    searchCurrentIndex.value =
        (searchCurrentIndex.value - 1 + searchMatches.value) %
        searchMatches.value;
  }

  // ==================== 书签 ====================

  Future<void> loadBookmarks() async {
    await bookmarks.loadAsync(
      () => _repo.getBookmarks(bookId.value),
      label: 'loadBookmarks',
    );
  }

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

  // ==================== 划词批注 ====================

  Future<void> loadHighlights() async {
    try {
      highlights.value = await note_api.listNotesInChapter(
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
      );
    } catch (_) {
      highlights.value = [];
    }
    HighlightPainter.invalidateCache();
  }

  void updateSelection(String text, int start, int end) {
    selectedText.value = text;
    selectionStart.value = start;
    selectionEnd.value = end;
    showSelectionToolbar.value = text.isNotEmpty;
  }

  void clearSelection() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    showSelectionToolbar.value = false;
  }

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
      await loadHighlights();
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存高亮失败';
    }
  }

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
      await loadHighlights();
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存笔记失败';
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await note_api.deleteNote(noteId: noteId);
      hapticFeedback(HapticType.heavy);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '删除失败';
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await note_api.upsertNote(note: note);
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
    translationContent.value = content;
    if (readingMode.value == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

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
