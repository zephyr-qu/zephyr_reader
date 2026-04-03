import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';
import 'package:zephyr_reader/domain/models/chapter.dart';
import 'package:zephyr_reader/features/reader/application/services/chapter_content_service.dart';
import 'package:zephyr_reader/features/reader/data/reading_progress_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart';

import '../domain/repositories/reader_repository.dart';
import '../../../core/reader/reader_config.dart';

/// 阅读模式
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 左右翻页
  pagination,
}

/// 阅读器视图模型
///
/// 统一管理阅读器所有状态和业务逻辑
@injectable
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;
  final ChapterContentService _contentService;
  final ReadingProgressService _progressService;
  final BookshelfService _bookshelfService;

  // ==================== 书籍状态 ====================

  /// 当前书籍 ID
  final bookId = signal<int>(0);

  /// 当前章节 ID
  final chapterId = signal<int>(0);

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

  // ==================== UI 状态 ====================

  /// 是否正在加载
  final isLoading = signal<bool>(false);

  /// 错误信息
  final error = signal<String?>(null);

  /// 是否显示目录
  final showCatalog = signal<bool>(false);

  /// 是否显示设置面板
  final showSettings = signal<bool>(false);

  /// 是否显示书签
  final showBookmarks = signal<bool>(false);

  /// 是否显示工具栏
  final showToolbar = signal<bool>(true);

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

  // ==================== 阅读统计 ====================

  /// 阅读时长（秒）
  final readingDuration = signal<int>(0);

  /// 是否正在阅读（计时）
  final isReading = signal<bool>(false);

  // ==================== 书签 ====================

  /// 书签列表
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  // ==================== 定时器 ====================

  Timer? _readingTimer;
  Timer? _saveTimer;

  ReaderViewModel(
    this._repo,
    this._config,
    this._contentService,
    this._progressService,
    this._bookshelfService,
  ) {
    // 从配置加载设置
    _loadSettings();

    // 监听自动滚动设置
    effect(() {
      if (_config.autoScroll.value && isReading.value) {
        _startAutoScroll();
      } else {
        _stopAutoScroll();
      }
    });
  }

  /// 加载设置
  void _loadSettings() {
    fontSize.value = _config.fontSize.value.size.toDouble();
    lineHeight.value = _config.lineHeight.value;
    themeMode.value = _mapThemeToThemeMode(_config.theme.value);
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

  /// 初始化阅读器
  Future<void> initialize(int bookId, {int initialChapterId = 0}) async {
    this.bookId.value = bookId;

    isLoading.value = true;
    error.value = null;

    try {
      // 加载章节列表
      await loadChapters();

      // 加载阅读进度
      await _loadLastProgress();

      // 加载初始章节
      if (chapters.value.value != null && chapters.value.value!.isNotEmpty) {
        final targetChapterId = initialChapterId > 0
            ? initialChapterId
            : chapters.value.value!.first.id;
        await loadChapter(targetChapterId);
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
      final data = await _bookshelfService.getBookChapters(bookId.value);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      chapters.value = AsyncState.error(e);
      rethrow;
    }
  }

  /// 加载上次的阅读进度
  Future<void> _loadLastProgress() async {
    final result = await _progressService.loadReadingProgress(bookId.value);
    if (result.isSuccess) {
      final progress = result.value;
      if (progress != null) {
        chapterId.value = progress.chapterId;
        pageIndex.value = progress.pageIndex;
        totalPages.value = progress.totalPages;
        readingDuration.value = progress.readingTimeSeconds;

        // 找到对应的章节索引
        final chapterList = chapters.value.value ?? [];
        final index = chapterList.indexWhere((c) => c.id == progress.chapterId);
        if (index != -1) {
          chapterIndex.value = index;
        }
      }
    }
  }

  /// 加载章节内容
  Future<void> loadChapter(int chapterId) async {
    this.chapterId.value = chapterId;
    chapterContent.value = AsyncState.loading();
    isLoading.value = true;

    try {
      // 使用内容服务加载
      final content = await _contentService.loadChapterContent(
        bookId.value,
        chapterId,
      );

      // 计算分页
      final pages = await _contentService.calculatePages(
        bookId: bookId.value,
        chapterId: chapterId,
        fontSize: fontSize.value,
        lineHeight: lineHeight.value,
        width: pageWidth.value,
        height: pageHeight.value,
        padding: 16,
      );

      chapterContent.value = AsyncState.data(content);
      totalPages.value = pages.length;

      // 更新章节索引
      final chapterList = chapters.value.value ?? [];
      final index = chapterList.indexWhere((c) => c.id == chapterId);
      if (index != -1) {
        chapterIndex.value = index;
      }

      // 保存阅读历史
      await _repo.saveReadingHistory(bookId.value, chapterId, 0, 0);
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
    await _saveProgress();
  }

  /// 上一章
  Future<void> previousChapter() async {
    if (chapterIndex.value > 0) {
      final chapterList = chapters.value.value ?? [];
      final newChapter = chapterList[chapterIndex.value - 1];
      await loadChapter(newChapter.id);
      pageIndex.value = 0;
    }
  }

  /// 下一章
  Future<void> nextChapter() async {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value < chapterList.length - 1) {
      final newChapter = chapterList[chapterIndex.value + 1];
      await loadChapter(newChapter.id);
      pageIndex.value = 0;
    }
  }

  /// 跳转到指定章节
  Future<void> jumpToChapter(int chapterId) async {
    await loadChapter(chapterId);
    pageIndex.value = 0;
    showCatalog.value = false;
  }

  /// 上一页
  void previousPage() {
    if (pageIndex.value > 0) {
      pageIndex.value--;
    }
  }

  /// 下一页
  void nextPage() {
    if (pageIndex.value < totalPages.value - 1) {
      pageIndex.value++;
    }
  }

  /// 开始阅读计时
  void startReading() {
    if (isReading.value) return;
    isReading.value = true;

    _readingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      readingDuration.value++;
    });
  }

  /// 停止阅读计时
  Future<void> stopReading() async {
    if (!isReading.value) return;
    isReading.value = false;
    _readingTimer?.cancel();

    // 保存阅读时长
    await _saveProgress();
    readingDuration.value = 0;
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
    final result = await _progressService.updateReadingProgress(
      bookId: bookId.value,
      chapterId: chapterId.value,
      pageIndex: pageIndex.value,
      totalPages: totalPages.value,
      readingTimeSeconds: readingDuration.value,
    );
    if (result.isFailure) {
      debugPrint('ReaderViewModel._saveProgress error: ${result.error}');
    }
  }

  /// 切换目录显示
  void toggleCatalog() {
    showCatalog.value = !showCatalog.value;
    showSettings.value = false;
    showBookmarks.value = false;
  }

  /// 切换设置面板显示
  void toggleSettings() {
    showSettings.value = !showSettings.value;
    showCatalog.value = false;
    showBookmarks.value = false;
  }

  /// 切换书签显示
  void toggleBookmarks() {
    showBookmarks.value = !showBookmarks.value;
    showCatalog.value = false;
    showSettings.value = false;
  }

  /// 切换工具栏显示
  void toggleToolbar() {
    showToolbar.value = !showToolbar.value;
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
  Future<bool> addBookmark(String? note) async {
    try {
      await _repo.addBookmark(
        bookId.value,
        chapterId.value,
        pageIndex.value,
        note,
      );
      await loadBookmarks();
      return true;
    } catch (e) {
      debugPrint('ReaderViewModel.addBookmark error: $e');
      return false;
    }
  }

  /// 删除书签
  Future<bool> deleteBookmark(int bookmarkId) async {
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
    if (bookmark.chapterId != chapterId.value) {
      await loadChapter(bookmark.chapterId);
    }
    pageIndex.value = bookmark.position;
    showBookmarks.value = false;
  }

  /// 检查当前位置是否已有书签
  bool get hasBookmarkAtCurrentPosition {
    final currentBookmarks = bookmarks.value.value ?? [];
    return currentBookmarks.any(
      (b) => b.chapterId == chapterId.value && b.position == pageIndex.value,
    );
  }

  /// 获取当前位置的书签（如果有）
  Bookmark? get currentBookmark {
    final currentBookmarks = bookmarks.value.value ?? [];
    try {
      return currentBookmarks.firstWhere(
        (b) => b.chapterId == chapterId.value && b.position == pageIndex.value,
      );
    } catch (_) {
      return null;
    }
  }

  /// 切换当前位置书签（有则删除，无则添加）
  Future<bool> toggleBookmarkAtCurrentPosition({String? note}) async {
    final existing = currentBookmark;
    if (existing != null) {
      return await deleteBookmark(existing.id);
    } else {
      return await addBookmark(note);
    }
  }

  /// 更新字体大小
  Future<void> setFontSize(double size) async {
    fontSize.value = size;
    await _config.setFontSize(ReaderFontSize.fromSize(size));
    // 重新计算分页
    await loadChapter(chapterId.value);
  }

  /// 更新行间距
  Future<void> setLineHeight(double height) async {
    lineHeight.value = height;
    await _config.setLineHeight(height);
    // 重新计算分页
    await loadChapter(chapterId.value);
  }

  /// 更新主题
  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final readerTheme = mode == ThemeMode.dark
        ? ReaderTheme.dark
        : ReaderTheme.light;
    await _config.setTheme(readerTheme);
  }

  /// 更新阅读模式
  void setReadingMode(ReadingMode mode) {
    readingMode.value = mode;
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

  /// 清理资源
  Future<void> dispose() async {
    await stopReading();
    _saveTimer?.cancel();
    _readingTimer?.cancel();
    _autoScrollTimer?.cancel();
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
}
