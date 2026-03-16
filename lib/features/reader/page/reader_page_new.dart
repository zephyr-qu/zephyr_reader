/// 阅读器页�?- 核心阅读功能
///
/// 功能�?/// - 支持上下滚动和左右翻页模�?/// - �?Rust 引擎集成，使用其分页功能
/// - 自动保存阅读进度
/// - 支持章节跳转
/// - 阅读设置（字体、间距、主题）
/// - 书签功能
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';

import '../application/services/reading_progress_service.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/reader_bottom_toolbar.dart';

/// 阅读模式
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 左右翻页
  pagination,
}

/// 书籍信息（简化版本）
class BookInfo {
  final String bookId;
  final String title;
  final String author;
  final int chapterCount;
  final int totalCharacters;
  final String filePath;
  final String fileType;
  final String? coverPath;

  BookInfo({
    required this.bookId,
    required this.title,
    required this.author,
    required this.chapterCount,
    required this.totalCharacters,
    required this.filePath,
    required this.fileType,
    this.coverPath,
  });
}

/// 章节信息（简化版本）
class ChapterInfo {
  final int chapterId;
  final String title;
  final int startIndex;
  final int endIndex;
  final int contentLength;
  final int index;

  ChapterInfo({
    required this.chapterId,
    required this.title,
    required this.startIndex,
    required this.endIndex,
    required this.contentLength,
    required this.index,
  });
}

/// 阅读器页�?
class ReaderPageNew extends HookWidget {
  /// 书籍 ID
  final int bookId;

  /// 初始章节 ID
  final int initialChapterId;

  /// 初始页码
  final int initialPageIndex;

  const ReaderPageNew({
    super.key,
    required this.bookId,
    required this.initialChapterId,
    this.initialPageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 状态信�?
    final bookInfo = useSignal<BookInfo?>(null);
    final chapters = useSignal<List<ChapterInfo>>([]);
    final currentChapterId = useSignal(initialChapterId);
    final currentPageIndex = useSignal(initialPageIndex);
    final totalPages = useSignal(0);
    final isLoading = useSignal(true);
    final error = useSignal<String?>(null);

    // UI 状�?
   final showToolbar = useSignal(false);
    final showChapterList = useSignal(false);
    final showSettings = useSignal(false);
    final showBookmarks = useSignal(false);
    final readingMode = useSignal(ReadingMode.scroll);

    // 阅读设置
    final fontSize = useSignal(18.0);
    final lineHeight = useSignal(1.5);
    final themeMode = useSignal(ThemeMode.light);

    // 进度服务
    final progressService = useMemoized(() {
      // 使用空的 SharedPreferences 实例
      return ReadingProgressService(null);
    });
    useEffect(() {
      _loadBookInfo(context, bookId, bookInfo, chapters, isLoading, error);
      return null;
    }, []);

    // 保存进度定时�?
     Timer? saveTimer;
    useEffect(() {
      saveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _saveProgress(
          progressService,
          bookId,
          currentChapterId.value,
          currentPageIndex.value,
          totalPages.value,
        );
      });
      return () => saveTimer?.cancel();
    }, []);

    // 监听页面变化自动保存
    useEffect(() {
      final chapterId = currentChapterId.value;
      final pageIndex = currentPageIndex.value;

      saveTimer?.cancel();
      saveTimer = Timer(const Duration(seconds: 2), () {
        _saveProgress(
          progressService,
          bookId,
          chapterId,
          pageIndex,
          totalPages.value,
        );
      });
      return () => saveTimer?.cancel();
    }, [currentChapterId.value, currentPageIndex.value]);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _saveProgress(
            progressService,
            bookId,
            currentChapterId.value,
            currentPageIndex.value,
            totalPages.value,
          );
        }
      },
      child: Scaffold(
        body: Container(
          color: _getBackgroundColor(themeMode.value),
          child: SafeArea(
            child: Stack(
              children: [
                // 阅读区域
                _buildReadingArea(
                  context,
                  bookInfo.value,
                  chapters.value,
                  currentChapterId.value,
                  currentPageIndex.value,
                  isLoading.value,
                  error.value,
                  readingMode.value,
                  fontSize.value,
                  lineHeight.value,
                  themeMode.value,
                  onChapterChanged: (chapterId) =>
                      currentChapterId.value = chapterId,
                  onPageChanged: (pageIndex) =>
                      currentPageIndex.value = pageIndex,
                  onTotalPagesChanged: (total) => totalPages.value = total,
                ),
                // 顶部工具�?
                    AnimatedOpacity(
                  opacity: showToolbar.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildTopBar(
                    context,
                    bookInfo.value,
                    themeMode.value,
                    onClose: () => context.pop(),
                    onToggleToolbar: () =>
                        showToolbar.value = !showToolbar.value,
                    onShowChapterList: () => showChapterList.value = true,
                    onShowBookmarks: () => showBookmarks.value = true,
                  ),
                ),
                // 底部工具�?
                     AnimatedOpacity(
                  opacity: showToolbar.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildBottomBar(
                    context,
                    currentChapterId.value,
                    currentPageIndex.value,
                    totalPages.value,
                    themeMode.value,
                    onPreviousChapter: () =>
                        _previousChapter(chapters.value, currentChapterId),
                    onNextChapter: () =>
                        _nextChapter(chapters.value, currentChapterId),
                    onPreviousPage: () {
                      if (currentPageIndex.value > 0) {
                        currentPageIndex.value--;
                      }
                    },
                    onNextPage: () {
                      if (currentPageIndex.value < totalPages.value - 1) {
                        currentPageIndex.value++;
                      }
                    },
                    onShowSettings: () => showSettings.value = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadBookInfo(
    BuildContext context,
    int bookId,
    Signal<BookInfo?> bookInfo,
    Signal<List<ChapterInfo>> chapters,
    Signal<bool> isLoading,
    Signal<String?> error,
  ) async {
    try {
      // 从数据库加载书籍信息
      // TODO: 调用 BookshelfService.getBookDetail(bookId) 获取书籍信息
      // 这里使用示例数据
      bookInfo.value = BookInfo(
        bookId: bookId.toString(),
        title: '示例书籍',
        author: '作�?',
        chapterCount: 10,
        totalCharacters: 100000,
        filePath: '/path/to/book.txt',
        fileType: 'txt',
        coverPath: null,
      );

      // 加载章节列表
      // TODO: 调用 BookshelfService.getBookChapters(bookId) 获取章节列表
      chapters.value = List.generate(
        10,
        (index) => ChapterInfo(
          chapterId: index,
          title: '�?{index + 1}�?',
          startIndex: index * 10000,
          endIndex: (index + 1) * 10000,
          contentLength: 10000,
          index: index,
        ),
      );

      isLoading.value = false;
    } catch (e) {
      error.value = '加载失败�?e';
      isLoading.value = false;
    }
  }

  void _saveProgress(
    ReadingProgressService service,
    int bookId,
    int chapterId,
    int pageIndex,
    int totalPages,
  ) {
    service.updateReadingProgress(
      bookId: bookId,
      chapterId: chapterId,
      pageIndex: pageIndex,
      totalPages: totalPages,
    );
  }

  Widget _buildReadingArea(
    BuildContext context,
    BookInfo? bookInfo,
    List<ChapterInfo> chapters,
    int currentChapterId,
    int currentPageIndex,
    bool isLoading,
    String? error,
    ReadingMode mode,
    double fontSize,
    double lineHeight,
    ThemeMode themeMode, {
    required ValueChanged<int> onChapterChanged,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onTotalPagesChanged,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(error, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // 重新加载
              },
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        // 点击切换工具�?
            },
      child: mode == ReadingMode.scroll
          ? _buildScrollMode(
              context,
              bookInfo,
              currentChapterId,
              fontSize,
              lineHeight,
              themeMode,
              onPageChanged: onPageChanged,
              onTotalPagesChanged: onTotalPagesChanged,
            )
          : _buildPaginationMode(
              context,
              bookInfo,
              currentChapterId,
              currentPageIndex,
              fontSize,
              lineHeight,
              themeMode,
              onPageChanged: onPageChanged,
              onTotalPagesChanged: onTotalPagesChanged,
            ),
    );
  }

  Widget _buildScrollMode(
    BuildContext context,
    BookInfo? bookInfo,
    int currentChapterId,
    double fontSize,
    double lineHeight,
    ThemeMode themeMode, {
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onTotalPagesChanged,
  }) {
    // 实现滚动模式
    // TODO: 完善滚动模式的实现，包括连续滚动、自动加载等
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        '这是滚动模式的示例内容。\n\n' * 50,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: themeMode == ThemeMode.dark
              ? Colors.grey[300]
              : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPaginationMode(
    BuildContext context,
    BookInfo? bookInfo,
    int currentChapterId,
    int currentPageIndex,
    double fontSize,
    double lineHeight,
    ThemeMode themeMode, {
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onTotalPagesChanged,
  }) {
    return ReaderContent(
      bookId: bookInfo?.bookId ?? '',
      chapterId: currentChapterId,
      pageIndex: currentPageIndex,
      fontSize: fontSize,
      lineHeight: lineHeight,
      themeMode: themeMode,
      onPageChanged: onPageChanged,
      onTotalPagesChanged: onTotalPagesChanged,
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    BookInfo? bookInfo,
    ThemeMode themeMode, {
    required VoidCallback onClose,
    required VoidCallback onToggleToolbar,
    required VoidCallback onShowChapterList,
    required VoidCallback onShowBookmarks,
  }) {
    return ReaderToolbar(
      title: bookInfo?.title ?? '阅读�?',
      themeMode: themeMode,
      onClose: onClose,
      onToggleToolbar: onToggleToolbar,
      onShowChapterList: onShowChapterList,
      onShowBookmarks: onShowBookmarks,
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    int currentChapterId,
    int currentPageIndex,
    int totalPages,
    ThemeMode themeMode, {
    required VoidCallback onPreviousChapter,
    required VoidCallback onNextChapter,
    required VoidCallback onPreviousPage,
    required VoidCallback onNextPage,
    required VoidCallback onShowSettings,
  }) {
    return ReaderBottomToolbar(
      currentChapterId: currentChapterId,
      currentPageIndex: currentPageIndex,
      totalPages: totalPages,
      themeMode: themeMode,
      onPreviousChapter: onPreviousChapter,
      onNextChapter: onNextChapter,
      onPreviousPage: onPreviousPage,
      onNextPage: onNextPage,
      onShowSettings: onShowSettings,
    );
  }

  void _previousChapter(
    List<ChapterInfo> chapters,
    Signal<int> currentChapterId,
  ) {
    if (currentChapterId.value > 0) {
      currentChapterId.value--;
    }
  }

  void _nextChapter(List<ChapterInfo> chapters, Signal<int> currentChapterId) {
    if (currentChapterId.value < chapters.length - 1) {
      currentChapterId.value++;
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF1a1a1a);
      case ThemeMode.light:
      default:
        return const Color(0xFFF5F5DC); // 米黄色护眼背�?    }
  }
}
