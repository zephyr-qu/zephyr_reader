import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'package:zephyr_reader/core/local/rust_bilingual_service.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';

import '../../../core/reader/reader_config.dart';
import '../../statistics/application/reading_stats_service.dart';
import '../data/note_repository.dart';
import '../data/repositories/rust_reader_repository.dart';
import '../domain/services/highlight_painter.dart';

/// 阅读模式
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 仿真翻页
  pageTurn,

  /// 左右分页
  pagination,

  /// 双语对照
  bilingual,
}

/// 书写方向
enum WritingDirection {
  /// 横排
  horizontal,

  /// 竖排 (top-to-bottom, right-to-left)
  vertical,
}

/// 阅读器视图模型
///
/// 统一管理阅读器所有状态和业务逻辑
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;
  final ReadingStatsService _statsService;
  final NoteRepository _noteRepo;

  // ==================== 书籍状态 ====================

  /// 当前书籍 ID
  final bookId = signal<String>('0');

  /// 当前章节索引（从 0 开始）
  final chapterIndex = signal<int>(0);

  /// 章节列表
  final chapters = asyncSignal<List<Chapter>>(AsyncState.data([]));

  /// 当前章节内容
  final chapterContent = asyncSignal<String>(AsyncState.data(''));

  /// 总页数（分页模式）
  final totalPages = signal<int>(0);

  /// 当前页码
  final pageIndex = signal<int>(0);

  /// 当前阅读位置在章节内的字符偏移
  final currentCharOffset = signal<int>(0);

  /// 待消费的跳转目标偏移，用于通知阅读内容组件定位
  final pendingJumpCharOffset = signal<int?>(null);

  // ==================== UI 状态 ====================

  /// 是否正在加载
  final isLoading = signal<bool>(false);

  /// 错误信息
  final error = signal<String?>(null);

  /// 显示于 SnackBar 的瞬态消息
  final toastMessage = signal<String>('');

  /// 是否显示目录
  final showCatalog = signal<bool>(false);

  /// 是否显示书签
  final showBookmarks = signal<bool>(false);

  /// 是否显示工具栏
  final showToolbar = signal<bool>(false);

  /// 工具栏闲置降透明度 (1.0 → 0.6)
  final toolbarOpacity = signal<double>(1.0);

  final showSettings = signal<bool>(false);

  /// 阅读模式
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);

  // ==================== 阅读设置 ====================

  /// 字体大小
  final fontSize = signal<double>(18.0);

  /// 行间距
  final lineHeight = signal<double>(1.5);

  /// 主题模式
  final themeMode = signal<ThemeMode>(ThemeMode.light);

  /// 页面宽度
  final pageWidth = signal<double>(400);

  /// 页面高度
  final pageHeight = signal<double>(600);

  /// 自动滚动触发器
  final autoScrollTick = signal<int>(0);

  /// 字间距
  final letterSpacing = signal<double>(0.0);

  /// 段间距
  final paragraphSpacing = signal<double>(12.0);

  /// 页边距
  final pageMargin = signal<double>(16.0);

  /// 书写方向 (horizontal / vertical)
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
  );



  /// 阅读背景色预设 (0=默认, 1=羊皮纸, 2=奶油, 3=护眼绿, 4=灰色)
  final readerBgColorIndex = signal<int>(0);

  /// 亮度覆盖层透明度 (0.0=正常, 1.0=全黑)
  final brightnessOverlay = signal<double>(0.0);

  /// 进度已保存（瞬态，用于显示 ✓ 指示）
  final progressSaved = signal<bool>(false);

  // ==================== 页面内搜索 ====================

  final showSearch = signal<bool>(false);
  final searchQuery = signal<String>('');
  final searchMatches = signal<int>(0);
  final searchCurrentIndex = signal<int>(0);
  final searchMatchParagraph = signal<int>(-1);

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

  // ==================== 阅读统计 ====================

  /// 阅读时长（秒）
  final readingDuration = signal<int>(0);

  /// 是否正在阅读（计时）
  final isReading = signal<bool>(false);

  // ==================== 书签 ====================

  /// 书签列表
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  // ==================== 双语对照 ====================

  /// 双语对齐结果
  final bilingualAlignment = signal<BilingualAlignment?>(null);

  /// 对照译文内容（由外部设置）
  final translationContent = signal<String>('');

  /// 双语对齐是否正在加载
  final isBilingualLoading = signal<bool>(false);

  /// 双语对齐错误
  final bilingualError = signal<String?>(null);

  // ==================== 划词批注 ====================

  /// 当前选中的文本
  final selectedText = signal<String>('');

  /// 当前选中的起始偏移（在整个章节内容中的位置）
  final selectionStart = signal<int>(0);

  /// 当前选中的结束偏移
  final selectionEnd = signal<int>(0);

  /// 是否显示批注工具栏
  final showSelectionToolbar = signal<bool>(false);

  /// 当前章节的高亮列表
  final highlights = signal<List<Note>>([]);

  // ==================== 定时器 ====================

  Timer? _readingTimer;
  Timer? _saveTimer;
  final RustBilingualService _bilingualService;
  final List<void Function()> _disposers = [];

  ReaderViewModel(
    this._repo,
    this._config,
    this._statsService,
    this._noteRepo,
    this._bilingualService,
  ) {
    // 从配置加载设置
    _loadSettings();

    // 监听自动滚动设置
    _disposers.add(
      effect(() {
        if (_config.autoScroll.value && isReading.value) {
          _startAutoScroll();
        } else {
          _stopAutoScroll();
        }
      }),
    );
  }

  /// 加载设置
  void _loadSettings() {
    fontSize.value = _config.fontSize.value.size.toDouble();
    lineHeight.value = _config.lineHeight.value;
    themeMode.value = _mapThemeToThemeMode(_config.theme.value);
    paragraphSpacing.value = _config.paragraphSpacing.value;
    pageMargin.value = _config.padding.value;
  }

  /// 映射主题
  ThemeMode _mapThemeToThemeMode(ReaderTheme theme) {
    switch (theme) {
      case ReaderTheme.dark:
        return ThemeMode.dark;
      case ReaderTheme.sepia:
      case ReaderTheme.light:
        return ThemeMode.light;
    }
  }

  static const int _preloadCount = 3;

  bool _initialized = false;

  /// 初始化阅读器
  Future<void> initialize(String bookId, {int initialChapterId = 0}) async {
    if (_initialized && this.bookId.value == bookId) return;
    _initialized = true;
    this.bookId.value = bookId;
    currentCharOffset.value = 0;

    isLoading.value = true;
    error.value = null;

    try {
      // 加载章节列表
      await loadChapters();

      // 加载阅读进度
      await _loadLastProgress();

      // 加载初始章节
      final chaptersList = chapters.value.value;
      if (chaptersList != null && chaptersList.isNotEmpty) {
        final restoredChapterIndex = chapterIndex.value;
        final restoredCharOffset = currentCharOffset.value;
        final targetChapterIndex = initialChapterId > 0
            ? initialChapterId
            : restoredChapterIndex;
        final targetCharOffset =
            initialChapterId > 0 && initialChapterId != restoredChapterIndex
            ? 0
            : restoredCharOffset;
        await loadChapter(
          targetChapterIndex,
          initialCharOffset: targetCharOffset,
          restartSession: false,
        );
        // 预加载前后章节
        _prefetchChapters(targetChapterIndex);
      }

      // 加载书签
      await loadBookmarks();

      // 开始计时
      startReading();

      // 启动定时保存（每 30 秒）
      _startAutoSave();
    } catch (e) {
      error.value = '加载失败：$e';
      debugPrint('ReaderViewModel.initialize error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载章节列表
  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final bookIdInt =
          int.tryParse(bookId.value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final data = await _repo.getChapters(bookIdInt);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      chapters.value = AsyncState.error(e);
      rethrow;
    }
  }

  /// 加载上次的阅读进度
  Future<void> _loadLastProgress() async {
    try {
      final progress = await _repo.loadReadingProgress(bookId.value);
      if (progress != null) {
        chapterIndex.value = progress.chapterIndex;
        currentCharOffset.value = progress.charOffset;
        readingDuration.value = progress.readingTimeSeconds.toInt();
      }
    } catch (_) {
      // 进度加载失败，使用默认值
    }
  }

  /// 加载章节内容
  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    bool restartSession = true,
  }) async {
    chapterContent.value = AsyncState.loading();
    isLoading.value = true;

    final previousChapterIndex = this.chapterIndex.value;
    final previousOffset = currentCharOffset.value;
    final shouldRestartSession =
        restartSession &&
        isReading.value &&
        _statsService.isSessionActive &&
        previousChapterIndex != chapterIndex;

    try {
      // 使用内容服务加载
      final content = await _repo.loadChapterContent(
        bookId.value,
        chapterIndex,
      );

      // 计算分页
      final pages = await _repo.calculatePages(
        bookId: bookId.value,
        chapterId: chapterIndex,
        fontSize: fontSize.value,
        lineHeight: lineHeight.value,
        width: pageWidth.value,
        height: pageHeight.value,
        padding: 16,
      );

      chapterContent.value = AsyncState.data(content);
      totalPages.value = pages.length;

      // 更新章节索引
      this.chapterIndex.value = chapterIndex;
      currentCharOffset.value = initialCharOffset.clamp(0, content.length);
      pageIndex.value = _resolvePageIndexForOffset(
        pages,
        currentCharOffset.value,
      );
      pendingJumpCharOffset.value = currentCharOffset.value;
      error.value = null;

      // 加载当前章节的高亮
      await loadHighlights();

      // 章节级 GC：只保留前后 5 章
      _repo.gcChapterCache(bookId.value, chapterIndex);

      // 预加载前后章节（不阻塞 UI）
      _prefetchChapters(chapterIndex);

      if (shouldRestartSession) {
        _statsService.updateProgress(previousOffset);
        await _statsService.endReadingSession(previousOffset);
        _statsService.startReadingSession(
          bookId.value,
          chapterIndex,
          currentCharOffset.value,
        );
      }
    } catch (e) {
      chapterContent.value = AsyncState.error(e);
      error.value = '章节加载失败：$e';
      debugPrint('ReaderViewModel.loadChapter error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载指定页
  Future<void> loadPage(int pageIndex) async {
    if (pageIndex < 0 || pageIndex >= totalPages.value) {
      return;
    }

    this.pageIndex.value = pageIndex;
    final pages = _repo.getCachedPages(bookId.value, chapterIndex.value);
    if (pages != null && pageIndex < pages.length) {
      currentCharOffset.value = pages[pageIndex].startOffset;
    }
    _statsService.updateProgress(currentCharOffset.value);
    await _saveProgress();
  }

  /// 预加载前后章节到缓存
  void _prefetchChapters(int centerIndex) {
    final chapterList = chapters.value.value ?? [];
    if (chapterList.isEmpty) return;

    final start = (centerIndex - _preloadCount).clamp(
      0,
      chapterList.length - 1,
    );
    final end = (centerIndex + _preloadCount).clamp(0, chapterList.length - 1);

    for (int i = start; i <= end; i++) {
      if (i == centerIndex) continue;
      _repo.preloadChapter(bookId.value, i);
    }
  }

  /// 上一章
  Future<void> previousChapter() async {
    if (chapterIndex.value > 0) {
      final newChapterIndex = chapterIndex.value - 1;
      await loadChapter(newChapterIndex);
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value < chapterList.length - 1) {
      final newChapterIndex = chapterIndex.value + 1;
      await loadChapter(newChapterIndex);
    }
  }

  /// 跳转到指定章节
  Future<void> jumpToChapter(int chapterIndex) async {
    await loadChapter(chapterIndex);
    showCatalog.value = false;
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await loadChapter(chapterIndex, initialCharOffset: charOffset);
  }

  /// 上一页
  void previousPage() {
    if (pageIndex.value > 0) {
      loadPage(pageIndex.value - 1);
    }
  }

  /// 下一页
  void nextPage() {
    if (pageIndex.value < totalPages.value - 1) {
      loadPage(pageIndex.value + 1);
    }
  }

  /// 开始阅读计时
  void startReading() {
    if (isReading.value) return;
    isReading.value = true;

    _readingTimer?.cancel();
    if (!_statsService.isSessionActive) {
      _statsService.startReadingSession(
        bookId.value,
        chapterIndex.value,
        currentCharOffset.value,
      );
    }

    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readingDuration.value++;
    });
  }

  Future<void> stopReading() async {
    if (!isReading.value) return;
    isReading.value = false;
    _readingTimer?.cancel();

    await _statsService.endReadingSession(currentCharOffset.value);
    await _saveProgress();
  }

  /// 启动定时保存
  void _startAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveProgress();
    });
  }

  /// 保存阅读进度
  Future<void> _saveProgress() async {
    _statsService.updateProgress(currentCharOffset.value);
    try {
      await _repo.updateReadingProgress(
        bookId: bookId.value,
        chapterId: chapterIndex.value,
        charOffset: currentCharOffset.value,
        pageIndex: pageIndex.value,
        totalPages: totalPages.value,
        readingTimeSeconds: readingDuration.value,
      );

    } catch (e) {
      toastMessage.value = '保存阅读进度失败';
    }
  }

  /// 切换目录显示
  void toggleCatalog() {
    showCatalog.value = !showCatalog.value;
    showBookmarks.value = false;
  }

  /// 切换书签显示
  void toggleBookmarks() {
    showBookmarks.value = !showBookmarks.value;
    showCatalog.value = false;
  }

  /// 切换工具栏显示
  void toggleToolbar() {
    showToolbar.value = !showToolbar.value;
  }

  /// 切换设置面板显示
  void toggleSettings() {
    showSettings.value = !showSettings.value;
    showToolbar.value = showSettings.value;
  }

  /// 加载书签
  Future<void> loadBookmarks() async {
    bookmarks.value = AsyncState.loading();
    try {
      final data = await _repo.getBookmarks(bookId.value);
      bookmarks.value = AsyncState.data(data);
    } catch (e) {
      bookmarks.value = AsyncState.error(e);
    }
  }

  /// 添加书签
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
      debugPrint('ReaderViewModel.addBookmark error: $e');
      return false;
    }
  }

  /// 删除书签
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      final success = await _repo.deleteBookmark(bookmarkId);
      if (success) {
        await loadBookmarks();
      }
      return success;
    } catch (e) {
      debugPrint('ReaderViewModel.deleteBookmark error: $e');
      return false;
    }
  }

  /// 跳转到书签位置
  Future<void> jumpToBookmark(Bookmark bookmark) async {
    await jumpToPosition(bookmark.chapterIndex, bookmark.charOffset.toInt());
    showBookmarks.value = false;
  }

  /// 检查当前位置是否已有书签
  bool get hasBookmarkAtCurrentPosition {
    final currentBookmarks = bookmarks.value.value ?? [];
    return currentBookmarks.any(
      (b) =>
          b.chapterIndex == chapterIndex.value &&
          b.charOffset.toInt() == currentCharOffset.value,
    );
  }

  /// 获取当前位置的书签（如果有）
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

  /// 切换当前位置书签（有则删除，无则添加）
  Future<bool> toggleBookmarkAtCurrentPosition() async {
    final existing = currentBookmark;
    if (existing != null) {
      return await deleteBookmark(existing.id);
    } else {
      return await addBookmark();
    }
  }

  // ==================== 划词批注 ====================

  /// 加载当前章节的高亮和批注
  Future<void> loadHighlights() async {
    try {
      highlights.value = await _noteRepo.getNotesForChapter(
        bookId.value,
        chapterIndex.value,
      );
    } catch (_) {
      highlights.value = [];
    }
    HighlightPainter.invalidateCache();
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = chapterContent.value.value?.length ?? 0;
    currentCharOffset.value = charOffset.clamp(0, contentLength);
    _statsService.updateProgress(currentCharOffset.value);
  }

  void consumePendingJumpOffset() {
    pendingJumpCharOffset.value = null;
  }

  /// 更新选中文本
  void updateSelection(String text, int start, int end) {
    if (text.isEmpty || start == end) {
      clearSelection();
      return;
    }
    selectedText.value = text;
    selectionStart.value = start;
    selectionEnd.value = end;
    showSelectionToolbar.value = true;
  }

  /// 清除选中
  void clearSelection() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    showSelectionToolbar.value = false;
  }

  /// 保存高亮
  Future<void> saveHighlight() async {
    if (selectedText.value.isEmpty) return;
    try {
      final note = Note(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}_${chapterIndex.value}_${selectionStart.value}',
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        charOffset: selectionStart.value,
        length: selectionEnd.value - selectionStart.value,
        noteType: NoteType.highlight,
        content: selectedText.value,
        selectedText: selectedText.value,
        highlightColor: 0xFFFFEB3B,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _noteRepo.createNote(note);
      await HapticFeedback.mediumImpact();
      await loadHighlights();
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存高亮失败';
    }
  }

  /// 保存笔记
  Future<void> saveAnnotation(String annotationContent) async {
    if (selectedText.value.isEmpty || annotationContent.isEmpty) return;
    try {
      final note = Note(
        id: 'note_${DateTime.now().millisecondsSinceEpoch}_${chapterIndex.value}_${selectionStart.value}',
        bookId: bookId.value,
        chapterIndex: chapterIndex.value,
        charOffset: selectionStart.value,
        length: selectionEnd.value - selectionStart.value,
        noteType: NoteType.annotation,
        content: annotationContent,
        selectedText: selectedText.value,
        highlightColor: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _noteRepo.createNote(note);
      await loadHighlights();
      clearSelection();
    } catch (e) {
      toastMessage.value = '保存笔记失败';
    }
  }

  /// 删除高亮/笔记
  Future<void> deleteNote(String noteId) async {
    try {
      await _noteRepo.deleteNote(noteId);
      await HapticFeedback.heavyImpact();
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '删除失败';
    }
  }

  /// 更新笔记内容
  Future<void> updateNote(Note note) async {
    try {
      await _noteRepo.updateNote(note);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '更新笔记失败';
    }
  }

  /// 更新字体大小
  Future<void> setFontSize(double size) async {
    fontSize.value = size;
    await _config.setFontSize(ReaderFontSize.fromSize(size));
    // 重新计算分页
    await loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
    );
  }

  /// 更新行间距
  Future<void> setLineHeight(double height) async {
    lineHeight.value = height;
    await _config.setLineHeight(height);
    // 重新计算分页
    await loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
    );
  }

  /// 更新主题
  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final readerTheme = mode == ThemeMode.dark
        ? ReaderTheme.dark
        : ReaderTheme.light;
    await _config.setTheme(readerTheme);
  }

  /// 更新字间距
  void setLetterSpacing(double spacing) {
    letterSpacing.value = spacing;
  }

  /// 更新段间距
  void setParagraphSpacing(double spacing) {
    paragraphSpacing.value = spacing;
  }

  /// 更新页边距
  void setPageMargin(double margin) {
    pageMargin.value = margin;
  }

  /// 更新书写方向
  void setWritingDirection(WritingDirection direction) {
    writingDirection.value = direction;
  }

  /// 更新阅读背景色
  void setReaderBgColor(int index) {
    readerBgColorIndex.value = index;
  }

  /// 更新亮度
  void setBrightness(double value) {
    brightnessOverlay.value = value.clamp(0.0, 1.0);
  }



  /// 更新阅读模式
  void setReadingMode(ReadingMode mode) {
    readingMode.value = mode;
    if (mode == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  /// 执行双语对齐
  Future<void> _runBilingualAlignment() async {
    if (translationContent.value.isEmpty) return;
    isBilingualLoading.value = true;
    bilingualError.value = null;
    try {
      final currentContent = chapterContent.value.value ?? '';
      if (currentContent.isEmpty) return;
      final result = await _bilingualService.alignBilingualContent(
        chineseContent: currentContent,
        englishContent: translationContent.value,
        minSimilarity: 0.5,
      );
      bilingualAlignment.value = result;
    } catch (e) {
      bilingualError.value = '双语对齐失败：$e';
    } finally {
      isBilingualLoading.value = false;
    }
  }

  /// 设置对照译文内容并自动对齐
  void setTranslationContent(String content) {
    translationContent.value = content;
    if (readingMode.value == ReadingMode.bilingual) {
      _runBilingualAlignment();
    }
  }

  /// 获取阅读进度百分比
  String get progressText {
    final totalChapters = chapters.value.value?.length ?? 0;
    if (totalChapters == 0) return '0%';

    final chapterProgress = (chapterIndex.value + 1) / totalChapters;
    return '${(chapterProgress * 100).toStringAsFixed(1)}%';
  }

  /// 获取当前章节标题
  String get currentChapterTitle {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value >= 0 && chapterIndex.value < chapterList.length) {
      return chapterList[chapterIndex.value].title;
    }
    return '加载中...';
  }

  /// 清理资源（可安全重复调用，lazySingleton 复用）
  Future<void> dispose() async {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _initialized = false;
    await stopReading();
    _saveTimer?.cancel();
    _readingTimer?.cancel();
    _autoScrollTimer?.cancel();

    bookId.value = '0';
    chapterIndex.value = 0;
    chapters.value = AsyncState.data([]);
    chapterContent.value = AsyncState.data('');
    totalPages.value = 0;
    pageIndex.value = 0;
    currentCharOffset.value = 0;
    pendingJumpCharOffset.value = null;
    isLoading.value = false;
    error.value = null;
    toastMessage.value = '';
    showCatalog.value = false;
    showBookmarks.value = false;
    showToolbar.value = false;
    toolbarOpacity.value = 1.0;
    showSettings.value = false;
    progressSaved.value = false;
    readingDuration.value = 0;
    isReading.value = false;
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
    bilingualAlignment.value = null;
    translationContent.value = '';
    isBilingualLoading.value = false;
    bilingualError.value = null;
  }

  // ==================== 自动滚动 ====================

  Timer? _autoScrollTimer;

  void _startAutoScroll() {
    _stopAutoScroll();
    _autoScrollTimer = Timer.periodic(
      Duration(seconds: _config.autoScrollSpeed.value),
      (timer) {
        autoScrollTick.value++;
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  int _resolvePageIndexForOffset(List<PageInfo> pages, int charOffset) {
    if (pages.isEmpty) {
      return 0;
    }
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (charOffset >= page.startOffset && charOffset < page.endOffset) {
        return i;
      }
    }
    return pages.length - 1;
  }
}
