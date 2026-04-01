/// 阅读器页面
///
/// 功能：
/// - 支持上下滚动和左右翻页模式
/// - 与 Rust 引擎集成，使用其分页功能
/// - 自动保存阅读进度
/// - 支持章节跳转
/// - 阅读设置（字体、间距、主题）
/// - 书签功能
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';

import '../domain/models/book_Info.dart';
import '../domain/models/chapter_info.dart';
import '../data/reading_progress_service.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/reader_bottom_toolbar.dart';
import '../../../core/database/database.dart';
import '../../bookshelf/application/services/bookshelf_service.dart';

/// 阅读模式
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 左右翻页
  pagination,
}

/// 阅读器页面
class ReaderPage extends HookWidget {
  /// 书籍 ID
  final int bookId;

  /// 初始章节 ID
  final int initialChapterId;

  /// 初始页码
  final int initialPageIndex;

  const ReaderPage({
    super.key,
    required this.bookId,
    required this.initialChapterId,
    this.initialPageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 状态信号
    final bookInfo = useSignal<BookInfo?>(null);
    final chapters = useListSignal<ChapterInfo>([]);
    final currentChapterId = useSignal(initialChapterId);
    final currentPageIndex = useSignal(initialPageIndex);
    final totalPages = useSignal(0);
    final isLoading = useSignal(true);
    final error = useSignal<String?>(null);

    // UI 状态
    final showToolbar = useSignal(false);
    final showChapterList = useSignal(false);
    final showSettings = useSignal(false);
    final showBookmarks = useSignal(false);
    final readingMode = useSignal(ReadingMode.scroll);

    // 阅读设置
    final fontSize = useSignal(18.0);
    final lineHeight = useSignal(1.5);
    final themeMode = useSignal(ThemeMode.light);

    // 阅读时长
    final readingDuration = useSignal(0);
    final readingTimer = useRef<Timer?>(null);

    // 进度服务
    final progressService = useMemoized(() {
      // 使用 getDatabase() 获取 AppDatabase 实例
      return ReadingProgressService(getDatabase());
    });

    // 加载书籍信息
    useEffect(() {
      _loadBookInfo(context, bookId, bookInfo, chapters, isLoading, error);
      _startReadingTimer(readingDuration, readingTimer);
      return () {
        _stopReadingTimer(readingTimer);
        _saveProgress(
          progressService,
          bookId,
          currentChapterId.value,
          currentPageIndex.value,
          totalPages.value,
          readingDuration.value,
        );
      };
    }, []);

    // 监听页面变化自动保存
    useEffect(() {
      final chapterId = currentChapterId.value;
      final pageIndex = currentPageIndex.value;

      _saveProgress(
        progressService,
        bookId,
        chapterId,
        pageIndex,
        totalPages.value,
        readingDuration.value,
      );
      return null;
    }, [currentChapterId.value, currentPageIndex.value]);

    // 切换工具栏显示
    final toggleToolbar = useCallback(() {
      showToolbar.value = !showToolbar.value;
      showSettings.value = false;
      showChapterList.value = false;
      showBookmarks.value = false;
    }, []);

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
            readingDuration.value,
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
                // 顶部工具栏
                AnimatedOpacity(
                  opacity: showToolbar.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildTopBar(
                    context,
                    bookInfo.value,
                    themeMode.value,
                    onClose: () => context.pop(),
                    onToggleToolbar: toggleToolbar,
                    onShowChapterList: () {
                      showChapterList.value = true;
                      showSettings.value = false;
                      showBookmarks.value = false;
                    },
                    onShowBookmarks: () {
                      showBookmarks.value = true;
                      showSettings.value = false;
                      showChapterList.value = false;
                    },
                  ),
                ),
                // 底部工具栏
                AnimatedOpacity(
                  opacity: showToolbar.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: _buildBottomBar(
                    context,
                    currentChapterId.value,
                    currentPageIndex.value,
                    totalPages.value,
                    themeMode.value,
                    onPreviousChapter: () => _previousChapter(
                      chapters.value,
                      currentChapterId,
                      currentPageIndex,
                    ),
                    onNextChapter: () => _nextChapter(
                      chapters.value,
                      currentChapterId,
                      currentPageIndex,
                    ),
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
                    onShowSettings: () {
                      showSettings.value = true;
                      showChapterList.value = false;
                      showBookmarks.value = false;
                    },
                  ),
                ),
                // 章节列表面板
                if (showChapterList.value)
                  _buildChapterListPanel(
                    context,
                    chapters.value,
                    currentChapterId.value,
                    themeMode.value,
                    onChapterSelected: (chapterId) {
                      currentChapterId.value = chapterId;
                      currentPageIndex.value = 0;
                      showChapterList.value = false;
                    },
                    onClose: () => showChapterList.value = false,
                  ),
                // 设置面板
                if (showSettings.value)
                  _buildSettingsPanel(
                    context,
                    themeMode.value,
                    readingMode.value,
                    fontSize.value,
                    lineHeight.value,
                    onReadingModeChanged: (mode) => readingMode.value = mode,
                    onFontSizeChanged: (size) => fontSize.value = size,
                    onLineHeightChanged: (height) => lineHeight.value = height,
                    onThemeChanged: (mode) => themeMode.value = mode,
                    onClose: () => showSettings.value = false,
                  ),
                // 书签面板
                if (showBookmarks.value)
                  _buildBookmarksPanel(
                    context,
                    themeMode.value,
                    onClose: () => showBookmarks.value = false,
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
    ListSignal<ChapterInfo> chapters,
    Signal<bool> isLoading,
    Signal<String?> error,
  ) async {
    try {
      // 调用 BookshelfService 获取书籍信息
      final bookshelfService = GetIt.I.get<BookshelfService>();
      final book = await bookshelfService.getBookDetail(bookId);

      if (book == null) {
        throw Exception('书籍不存在');
      }

      bookInfo.value = BookInfo(
        bookId: book.id.toString(),
        title: book.title,
        author: book.author,
        chapterCount: book.totalChapters,
        totalCharacters: book.totalCharacters,
        filePath: book.filePath,
        fileType: book.fileType,
        coverPath: book.coverPath,
      );

      // 加载章节列表
      final chapterList = await bookshelfService.getBookChapters(bookId);

      chapters.value = chapterList
          .map(
            (c) => ChapterInfo(
              chapterId: c.id,
              title: c.title,
              startIndex: 0,
              endIndex: 0,
              contentLength: c.wordCount,
              index: c.chapterIndex,
            ),
          )
          .toList();

      isLoading.value = false;
    } catch (e) {
      error.value = '加载失败：$e';
      isLoading.value = false;
    }
  }

  void _startReadingTimer(Signal<int> duration, ObjectRef<Timer?> timerRef) {
    timerRef.value = Timer.periodic(const Duration(seconds: 1), (timer) {
      duration.value++;
    });
  }

  void _stopReadingTimer(ObjectRef<Timer?> timerRef) {
    timerRef.value?.cancel();
    timerRef.value = null;
  }

  void _saveProgress(
    ReadingProgressService service,
    int bookId,
    int chapterId,
    int pageIndex,
    int totalPages,
    int duration,
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
        // 点击切换工具栏
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
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        '这是滚动模式的示例内容。\n\n' * 50,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: textColor,
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
      title: bookInfo?.title ?? '阅读器',
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

  Widget _buildChapterListPanel(
    BuildContext context,
    List<ChapterInfo> chapters,
    int currentChapterId,
    ThemeMode themeMode, {
    required ValueChanged<int> onChapterSelected,
    required VoidCallback onClose,
  }) {
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFF5F5DC);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '目录',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isCurrent = chapter.chapterId == currentChapterId;
                  return ListTile(
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent ? Colors.blue : textColor,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onChapterSelected(chapter.chapterId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(
    BuildContext context,
    ThemeMode themeMode,
    ReadingMode readingMode,
    double fontSize,
    double lineHeight, {
    required ValueChanged<ReadingMode> onReadingModeChanged,
    required ValueChanged<double> onFontSizeChanged,
    required ValueChanged<double> onLineHeightChanged,
    required ValueChanged<ThemeMode> onThemeChanged,
    required VoidCallback onClose,
  }) {
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFF5F5DC);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '设置',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 阅读模式
                  _buildSettingSection(
                    title: '阅读模式',
                    child: Row(
                      children: [
                        _buildChoiceChip(
                          label: '滚动',
                          selected: readingMode == ReadingMode.scroll,
                          onTap: () => onReadingModeChanged(ReadingMode.scroll),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '分页',
                          selected: readingMode == ReadingMode.pagination,
                          onTap: () =>
                              onReadingModeChanged(ReadingMode.pagination),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 字体大小
                  _buildSettingSection(
                    title: '字体大小：${fontSize.toStringAsFixed(1)}',
                    child: Slider(
                      value: fontSize,
                      min: 12,
                      max: 32,
                      divisions: 20,
                      onChanged: onFontSizeChanged,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 行间距
                  _buildSettingSection(
                    title: '行间距：${lineHeight.toStringAsFixed(1)}',
                    child: Slider(
                      value: lineHeight,
                      min: 1.0,
                      max: 3.0,
                      divisions: 20,
                      onChanged: onLineHeightChanged,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 主题
                  _buildSettingSection(
                    title: '主题',
                    child: Row(
                      children: [
                        _buildChoiceChip(
                          label: '浅色',
                          selected: themeMode == ThemeMode.light,
                          onTap: () => onThemeChanged(ThemeMode.light),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '深色',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => onThemeChanged(ThemeMode.dark),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? textColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor),
        ),
        child: Text(label, style: TextStyle(color: textColor)),
      ),
    );
  }

  Widget _buildBookmarksPanel(
    BuildContext context,
    ThemeMode themeMode, {
    required VoidCallback onClose,
  }) {
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFF5F5DC);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '书签',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: Icon(Icons.bookmark, color: textColor),
                    title: Text('暂无书签', style: TextStyle(color: textColor)),
                    subtitle: Text(
                      '阅读时点击书签按钮添加',
                      style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousChapter(
    List<ChapterInfo> chapters,
    Signal<int> currentChapterId,
    Signal<int> currentPageIndex,
  ) {
    if (currentChapterId.value > 0) {
      currentChapterId.value--;
      currentPageIndex.value = 0;
    }
  }

  void _nextChapter(
    List<ChapterInfo> chapters,
    Signal<int> currentChapterId,
    Signal<int> currentPageIndex,
  ) {
    if (currentChapterId.value < chapters.length - 1) {
      currentChapterId.value++;
      currentPageIndex.value = 0;
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF1a1a1a);
      case ThemeMode.light:
      default:
        return const Color(0xFFF5F5DC); // 米黄色护眼背景
    }
  }
}
