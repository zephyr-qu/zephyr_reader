import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';

import '../../../core/reader/reader_config.dart';
import '../data/repositories/rust_reader_repository.dart';
import 'reader_enums.dart';
import 'reader_settings_controller.dart';
import 'bookmark_controller.dart';
import 'annotation_controller.dart';
import 'reader_search_controller.dart';
import 'bilingual_controller.dart';

/// 阅读器视图模型
///
/// 统一管理阅读器所有状态和业务逻辑
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;
  // final ReadingStatsService _statsService;
  final ReaderSettingsController _settingsController;
  final BookmarkController _bookmarkController;
  final ReaderSearchController _searchController;
  final AnnotationController _annotationController;
  final BilingualController _bilingualController;

  // ==================== 设置信号转发 ====================

  Signal<double> get fontSize => _settingsController.fontSize;
  Signal<double> get lineHeight => _settingsController.lineHeight;
  Signal<ReaderTheme> get themeMode => _settingsController.readerTheme;
  Signal<double> get letterSpacing => _settingsController.letterSpacing;
  Signal<double> get paragraphSpacing => _settingsController.paragraphSpacing;
  Signal<double> get pageMargin => _settingsController.pageMargin;
  Signal<WritingDirection> get writingDirection =>
      _settingsController.writingDirection;
  Signal<int> get readerBgColorIndex => _settingsController.readerBgColorIndex;
  Signal<double> get brightnessOverlay => _settingsController.brightnessOverlay;
  AsyncSignal<List<Bookmark>> get bookmarks => _bookmarkController.bookmarks;
  Signal<bool> get showSearch => _searchController.showSearch;
  Signal<String> get searchQuery => _searchController.searchQuery;
  Signal<int> get searchMatches => _searchController.searchMatches;
  Signal<int> get searchCurrentIndex => _searchController.searchCurrentIndex;
  Signal<int> get searchMatchParagraph =>
      _searchController.searchMatchParagraph;
  Signal<String> get selectedText => _annotationController.selectedText;
  Signal<int> get selectionStart => _annotationController.selectionStart;
  Signal<int> get selectionEnd => _annotationController.selectionEnd;
  Signal<bool> get showSelectionToolbar =>
      _annotationController.showSelectionToolbar;
  Signal<List<Note>> get highlights => _annotationController.highlights;
  AsyncSignal<BilingualAlignment?> get bilingualAlignment =>
      _bilingualController.bilingualAlignment;
  Signal<String> get translationContent =>
      _bilingualController.translationContent;

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

  // ==================== 阅读设置（委托给 SettingsController） ====================

  /// 页面宽度（逻辑像素）
  final pageWidth = signal<double>(400);

  /// 页面高度（逻辑像素）
  final pageHeight = signal<double>(600);

  /// 设备像素比，用于 dp → px 转换
  final devicePixelRatio = signal<double>(1.0);

  /// 字符宽度校准数据（首次排版前测量一次，缓存复用）
  final _calibration = signal<CalibrationData?>(null);

  /// 当前字体系列名（由 FontRepository 提供）
  String _fontFamily = 'Noto Sans SC';

  /// 设置字体信息并重新校准
  void updateFont(String fontFamily) {
    _fontFamily = fontFamily;
    _calibration.value = null; // 字体变化后校准失效
  }

  /// 自动滚动触发器
  final autoScrollTick = signal<int>(0);

  /// 进度已保存（瞬态，用于显示 ✓ 指示）
  final progressSaved = signal<bool>(false);

  // ==================== 页面内搜索（委托给 SearchController） ====================

  // ==================== 阅读统计 ====================

  /// 阅读时长（秒）
  final readingDuration = signal<int>(0);

  /// 是否正在阅读（计时）
  final isReading = signal<bool>(false);

  // ==================== 书签（委托给 BookmarkController） ====================

  // ==================== 双语对照（委托给 BilingualController） ====================

  // ==================== 划词批注（委托给 AnnotationController） ====================

  // ==================== 定时器 ====================

  Timer? _readingTimer;
  Timer? _saveTimer;
  final List<void Function()> _disposers = [];

  ReaderViewModel(
    this._repo,
    this._config,
    // this._statsService,
  ) : _settingsController = ReaderSettingsController(_config),
      _bookmarkController = BookmarkController(_repo),
      _searchController = ReaderSearchController(),
      _annotationController = AnnotationController(),
      _bilingualController = BilingualController() {
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

  static const int _preloadCount = 3;

  /// 初始化阅读器
  /// 每次调用都会重新加载（允许切换书籍）
  Future<void> initialize(String bookId, {int initialChapterId = 0}) async {
    if (this.bookId.value == bookId &&
        chapters.value.value?.isNotEmpty == true) {
      return;
    }
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
      await _bookmarkController.loadBookmarks(bookId);

      // 开始计时
      startReading();

      // 启动定时保存（每 30 秒）
      _startAutoSave();
    } catch (e) {
      error.value = '加载失败：$e';
      Logging.error('ReaderViewModel.initialize error', exception: e);
    } finally {
      isLoading.value = false;
    }
  }

  /// 加载章节列表
  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final data = await _repo.getChapters(bookId.value);
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
    final shouldRestartSession =
        restartSession &&
        isReading.value &&
        // _statsService.isSessionActive &&
        previousChapterIndex != chapterIndex;

    try {
      // 使用内容服务加载
      final content = await _repo.loadChapterContent(
        bookId.value,
        chapterIndex,
      );

      // 将章节内容索引到 FTS5（不阻塞 UI）
      unawaited(_indexForSearch(chapterIndex, content));

      // █ 字符宽度校准（仅首次执行，字体/字号/DPR 变化后重置） █
      if (_calibration.value == null) {
        _calibration.value = await calibrateSafely(
          fontSize: fontSize.value,
          devicePixelRatio: devicePixelRatio.value,
          fontFamily: _fontFamily,
        );
      }

      // █ 带 KV 缓存的分页排版（Replace 块） █
      List<PageInfo> pages;
      bool paginationFromCache = false;

      final result = await _repo.getPaginatedChapterPages(
        bookId: bookId.value,
        chapterIndex: chapterIndex,
        fontSize: fontSize.value,
        lineHeight: lineHeight.value,
        width: pageWidth.value,
        height: pageHeight.value,
        padding: 16,
        devicePixelRatio: devicePixelRatio.value,
        calibration: _calibration.value,
        fontFamily: _fontFamily,
      );

      if (result.isFallback) {
        // 降级：Rust 排版失败，回退到 Dart 粗略分页
        Logging.warning('loadChapter: Rust pagination fallback, using Dart approximate');
        pages = await _repo.calculatePages(
          bookId: bookId.value,
          chapterId: chapterIndex,
          fontSize: fontSize.value,
          lineHeight: lineHeight.value,
          width: pageWidth.value,
          height: pageHeight.value,
          padding: 16,
        );
      } else {
        pages = result.pages;
        paginationFromCache = result.cacheHit;
      }

      // █ 灰度期双写对比 █
      _compareNewVsOldPagination(pages, content, chapterIndex);

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

      Logging.debug(
        'loadChapter: pages=${pages.length} cacheHit=$paginationFromCache '
        'resolvePage=$pageIndex off=$currentCharOffset',
      );

      // 加载当前章节的高亮
      await loadHighlights();

      // 章节级 GC：只保留前后 5 章
      _repo.gcChapterCache(bookId.value, chapterIndex);

      // 预加载前后章节（不阻塞 UI）
      _prefetchChapters(chapterIndex);

      if (shouldRestartSession) {
        // _statsService.updateProgress(previousOffset);
        // await _statsService.endReadingSession(previousOffset);
        // _statsService.startReadingSession(
        //   bookId.value,
        //   chapterIndex,
        //   currentCharOffset.value,
        // );
      }
    } catch (e) {
      chapterContent.value = AsyncState.error(e);
      error.value = '章节加载失败：$e';
      Logging.error('ReaderViewModel.loadChapter error', exception: e);
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
    // _statsService.updateProgress(currentCharOffset.value);
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

  /// 将章节内容索引到 FTS5（不阻塞 UI，失败静默忽略）
  Future<void> _indexForSearch(int chapterIndex, String content) async {
    try {
      final chapterList = chapters.value.value ?? [];
      final title =
          chapterList
              .where((c) => c.chapterIndex == chapterIndex)
              .firstOrNull
              ?.title ??
          '';
      await search_api.indexChapter(
        bookId: bookId.value,
        chapterId: '${bookId.value}_$chapterIndex',
        chapterIndex: chapterIndex.toString(),
        chapterTitle: title,
        content: content,
      );
    } catch (_) {
      // 索引失败不阻塞阅读
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
    // if (!_statsService.isSessionActive) {
    //   _statsService.startReadingSession(
    //     bookId.value,
    //     chapterIndex.value,
    //     currentCharOffset.value,
    //   );
    // }

    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readingDuration.value++;
    });
  }

  Future<void> stopReading() async {
    if (!isReading.value) return;
    isReading.value = false;
    _readingTimer?.cancel();

    // await _statsService.endReadingSession(currentCharOffset.value);
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
    // _statsService.updateProgress(currentCharOffset.value);
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

  /// 加载书签
  Future<void> loadBookmarks() async {
    await _bookmarkController.loadBookmarks(bookId.value);
  }

  /// 添加书签
  Future<bool> addBookmark() async {
    return await _bookmarkController.addBookmark(
      bookId.value,
      chapterIndex.value,
      currentCharOffset.value,
    );
  }

  /// 删除书签
  Future<bool> deleteBookmark(String bookmarkId) async {
    return await _bookmarkController.deleteBookmark(bookmarkId, bookId.value);
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

  // ==================== 划词批注（委托给 AnnotationController） ====================

  /// 加载当前章节的高亮和批注
  Future<void> loadHighlights() async {
    await _annotationController.loadHighlights(
      bookId.value,
      chapterIndex.value,
    );
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = chapterContent.value.value?.length ?? 0;
    currentCharOffset.value = charOffset.clamp(0, contentLength);
    // _statsService.updateProgress(currentCharOffset.value);
  }

  void consumePendingJumpOffset() {
    pendingJumpCharOffset.value = null;
  }

  /// 更新选中文本
  void updateSelection(String text, int start, int end) =>
      _annotationController.updateSelection(text, start, end);

  /// 清除选中
  void clearSelection() => _annotationController.clearSelection();

  /// 保存高亮
  Future<void> saveHighlight() async {
    if (_annotationController.selectedText.value.isEmpty) {
      return;
    }
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

  /// 保存笔记
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

  /// 删除高亮/笔记
  Future<void> deleteNote(String noteId) async {
    try {
      await _annotationController.deleteNote(noteId);
      hapticFeedback(HapticType.heavy);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '删除失败';
    }
  }

  /// 更新笔记内容
  Future<void> updateNote(Note note) async {
    try {
      // await _annotationController.updateNote(note);
      await loadHighlights();
    } catch (e) {
      toastMessage.value = '更新笔记失败';
    }
  }

  /// 更新字体大小（委托 SettingsController 并触发重新分页）
  Future<void> setFontSize(double size) async {
    await _settingsController.setFontSize(size);
    _calibration.value = null; // 字号变化 → 校准失效
    await loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
    );
  }

  /// 更新行间距（委托 SettingsController 并触发重新分页）
  Future<void> setLineHeight(double height) async {
    await _settingsController.setLineHeight(height);
    await loadChapter(
      chapterIndex.value,
      initialCharOffset: currentCharOffset.value,
      restartSession: false,
    );
  }

  /// 更新主题
  Future<void> setTheme(ReaderTheme theme) async {
    await _settingsController.setTheme(theme);
  }

  /// 更新字间距
  void setLetterSpacing(double spacing) {
    _settingsController.setLetterSpacing(spacing);
  }

  /// 更新段间距
  void setParagraphSpacing(double spacing) {
    _settingsController.setParagraphSpacing(spacing);
  }

  /// 更新页边距
  void setPageMargin(double margin) {
    _settingsController.setPageMargin(margin);
  }

  /// 更新书写方向
  void setWritingDirection(WritingDirection direction) {
    _settingsController.setWritingDirection(direction);
  }

  /// 更新阅读背景色
  void setReaderBgColor(int index) {
    _settingsController.setReaderBgColor(index);
  }

  /// 更新亮度
  void setBrightness(double value) {
    _settingsController.setBrightness(value);
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
    final content = chapterContent.value.value ?? '';
    final translation = _bilingualController.translationContent.value;
    await _bilingualController.runAlignment(content, translation);
  }

  /// 设置对照译文内容并自动对齐
  void setTranslationContent(String content) {
    _bilingualController.translationContent.value = content;
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
  void dispose() {
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();
    _settingsController.dispose();
    _bookmarkController.dispose();
    _searchController.dispose();
    _annotationController.dispose();
    _bilingualController.dispose();
    isReading.value = false;
    _readingTimer?.cancel();
    _saveTimer?.cancel();
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

  /// 灰度期双写对比：后台异步比较新旧分页结果
  void _compareNewVsOldPagination(
    List<PageInfo> newPages,
    String content,
    int chapterIndex,
  ) {
    // 只在 Debug 模式下执行
    assert(() {
      // 异步执行，不阻塞 UI
      _comparePaginationAsync(newPages, content, chapterIndex);
      return true;
    }());
  }

  Future<void> _comparePaginationAsync(
    List<PageInfo> newPages,
    String content,
    int chapterIndex,
  ) async {
    try {
      final oldPages = _paginateApproximate(
        content,
        fontSize: fontSize.value,
        lineHeight: lineHeight.value,
        width: pageWidth.value,
        height: pageHeight.value,
        padding: 16,
      );

      if (newPages.length != oldPages.length) {
        Logging.warning(
          'PAGINATION MISMATCH chapter=$chapterIndex: '
          'new=${newPages.length} pages vs old=${oldPages.length} pages',
        );
      }

      // 逐页对比 offset 边界
      for (int i = 0; i < newPages.length && i < oldPages.length; i++) {
        final n = newPages[i];
        final o = oldPages[i];
        if (n.startOffset != o.startOffset || n.endOffset != o.endOffset) {
          final diff = (n.startOffset - o.startOffset).abs();
          if (diff > 5) {
            Logging.debug(
              'PAGE OFFSET DIFF page=$i: '
              'new=[${n.startOffset},${n.endOffset}] '
              'old=[${o.startOffset},${o.endOffset}] '
              'diff=$diff chars',
            );
          }
        }
      }
    } catch (e) {
      Logging.error('comparePaginationAsync error', exception: e);
    }
  }

  /// Dart 粗略分页（与 rust_reader_repository._paginateApproximate 一致）
  List<PageInfo> _paginateApproximate(
    String content, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    final maxWidth = width - padding * 2;
    final availableHeight = height - padding * 2;
    final charsPerLine = (maxWidth / fontSize).floor().clamp(10, 200);
    final linesPerPage = (availableHeight / (fontSize * lineHeight))
        .floor()
        .clamp(1, 100);
    final charsPerPage = charsPerLine * linesPerPage;

    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;

    while (offset < content.length) {
      var end = offset + charsPerPage;
      if (end >= content.length) {
        end = content.length;
      } else {
        final searchStart = (end - (charsPerLine ~/ 2)).clamp(
          0,
          content.length,
        );
        final newlinePos = content.lastIndexOf('\n', end);
        if (newlinePos > searchStart) {
          end = newlinePos + 1;
        } else {
          final paraBreak = content.lastIndexOf('\n\n', end);
          if (paraBreak > searchStart) {
            end = paraBreak + 2;
          }
        }
      }

      pages.add(
        PageInfo(
          pageIndex: pageIndex,
          content: content.substring(offset, end),
          richContent: null,
          startOffset: offset,
          endOffset: end,
        ),
      );
      offset = end;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(
        PageInfo(
          pageIndex: 0,
          content: content,
          richContent: null,
          startOffset: 0,
          endOffset: content.length,
        ),
      );
    }
    return pages;
  }
}
