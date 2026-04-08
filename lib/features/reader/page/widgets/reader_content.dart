/// 阅读器内容组件
///
/// 支持滚动和分页两种模式的内容渲染
/// - 滚动模式：使用 ListView 显示完整章节
/// - 分页模式：使用 PageView 支持左右翻页
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_hooks/signals_hooks.dart';

import '../../application/reader_view_model.dart';
import '../../application/services/chapter_content_service.dart';

/// 阅读器内容组件
class ReaderContent extends HookWidget {
  /// 书籍 ID
  final String bookId;

  /// 章节 ID
  final int chapterId;

  /// 当前页码（分页模式）
  final int pageIndex;

  /// 字体大小
  final double fontSize;

  /// 行间距
  final double lineHeight;

  /// 主题模式
  final ThemeMode themeMode;

  /// 阅读模式
  final ReadingMode readingMode;

  /// 页码变化回调
  final ValueChanged<int>? onPageChanged;

  /// 总页数变化回调
  final ValueChanged<int>? onTotalPagesChanged;

  /// 内容加载完成回调
  final VoidCallback? onContentLoaded;

  /// 自动滚动触发器（当值变化时触发滚动）
  final int? autoScrollTick;

  const ReaderContent({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    required this.readingMode,
    this.onPageChanged,
    this.onTotalPagesChanged,
    this.onContentLoaded,
    this.autoScrollTick,
  });

  @override
  Widget build(BuildContext context) {
    // 内容状态
    final content = useSignal<String>('');
    final isLoading = useSignal(true);
    final error = useSignal<String?>(null);
    final totalPages = useSignal(1);

    // 页面控制器（分页模式）
    final pageController = usePageController();

    // 滚动控制器（滚动模式）
    final scrollController = useScrollController();

    // 获取服务
    final contentService = useMemoized(
      () => GetIt.I.get<ChapterContentService>(),
    );

    // 加载章节内容
    useEffect(() {
      _loadChapterContent(
        contentService,
        content,
        isLoading,
        error,
        totalPages,
      );
      return null;
    }, [chapterId]);

    // 监听页码变化（分页模式）
    useEffect(() {
      if (readingMode == ReadingMode.pagination && pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        });
      }
      return null;
    }, [pageIndex, readingMode]);

    // 通知总页数变化
    useEffect(() {
      onTotalPagesChanged?.call(totalPages.value);
      return null;
    }, [totalPages.value]);

    // 通知内容加载完成
    useEffect(() {
      if (!isLoading.value && error.value == null) {
        onContentLoaded?.call();
      }
      return null;
    }, [isLoading.value, error.value]);

    // 自动滚动处理
    useEffect(() {
      if (autoScrollTick == null) return null;

      if (readingMode == ReadingMode.scroll && scrollController.hasClients) {
        // 滚动模式：向下滚动一定距离（约3行）
        final scrollAmount = fontSize * lineHeight * 3;
        final newPosition = scrollController.offset + scrollAmount;
        if (newPosition < scrollController.position.maxScrollExtent) {
          scrollController.animateTo(
            newPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else if (readingMode == ReadingMode.pagination &&
          pageController.hasClients) {
        // 分页模式：翻页
        final nextPage = pageIndex + 1;
        if (nextPage < totalPages.value) {
          pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          onPageChanged?.call(nextPage);
        }
      }
      return null;
    }, [autoScrollTick]);

    // 根据主题获取颜色
    final textColor = _getTextColor(themeMode);
    final backgroundColor = _getBackgroundColor(themeMode);

    return Container(
      color: backgroundColor,
      child: _buildContent(
        context,
        content.value,
        isLoading.value,
        error.value,
        textColor,
        backgroundColor,
        pageController,
        scrollController,
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String content,
    bool isLoading,
    String? error,
    Color textColor,
    Color backgroundColor,
    PageController pageController,
    ScrollController scrollController,
  ) {
    // 加载状态
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误状态
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // 触发重新加载
              },
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    // 根据阅读模式构建内容
    if (readingMode == ReadingMode.scroll) {
      return _buildScrollMode(
        content,
        textColor,
        backgroundColor,
        scrollController,
      );
    } else {
      return _buildPaginationMode(
        context,
        content,
        textColor,
        backgroundColor,
        pageController,
      );
    }
  }

  /// 滚动模式 - 显示完整章节内容
  Widget _buildScrollMode(
    String content,
    Color textColor,
    Color backgroundColor,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: SelectableText(
        content,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          color: textColor,
          fontFamily: 'Noto Sans SC',
        ),
        textAlign: TextAlign.justify,
      ),
    );
  }

  /// 分页模式 - 左右翻页
  Widget _buildPaginationMode(
    BuildContext context,
    String content,
    Color textColor,
    Color backgroundColor,
    PageController pageController,
  ) {
    // 获取屏幕尺寸用于分页
    final screenSize = MediaQuery.of(context).size;
    final padding = 16.0;

    // 使用缓存的分页数据（由 ReaderPage 的 ViewModel 计算）
    // 这里从 contentService 获取缓存的页面
    final contentService = GetIt.I.get<ChapterContentService>();
    final cachedPages = contentService.getCachedPages(bookId, chapterId);

    if (cachedPages != null && cachedPages.isNotEmpty) {
      return PageView.builder(
        controller: pageController,
        itemCount: cachedPages.length,
        onPageChanged: (index) {
          onPageChanged?.call(index);
        },
        itemBuilder: (context, index) {
          final page = cachedPages[index];
          return SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: SelectableText(
              page.content,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: textColor,
                fontFamily: 'Noto Sans SC',
              ),
              textAlign: TextAlign.justify,
            ),
          );
        },
      );
    }

    // 如果没有缓存，使用简化分页
    return _buildFallbackPagination(
      content,
      textColor,
      backgroundColor,
      pageController,
      screenSize,
      padding,
    );
  }

  /// fallback 分页显示（当没有缓存数据时）
  Widget _buildFallbackPagination(
    String content,
    Color textColor,
    Color backgroundColor,
    PageController pageController,
    Size screenSize,
    double padding,
  ) {
    // 计算每页字符数
    final charsPerPage = _estimateCharsPerPage(
      fontSize: fontSize,
      lineHeight: lineHeight,
      width: screenSize.width - (padding * 2),
      height: screenSize.height - (padding * 2),
      padding: padding,
    );

    // 分页
    final pages = _paginateContent(content, charsPerPage);

    if (pages.isEmpty) {
      return const Center(child: Text('内容为空'));
    }

    return PageView.builder(
      controller: pageController,
      itemCount: pages.length,
      onPageChanged: (index) {
        onPageChanged?.call(index);
      },
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: SelectableText(
            pages[index],
            style: TextStyle(
              fontSize: fontSize,
              height: lineHeight,
              color: textColor,
              fontFamily: 'Noto Sans SC',
            ),
            textAlign: TextAlign.justify,
          ),
        );
      },
    );
  }

  /// 估算每页字符数
  int _estimateCharsPerPage({
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) {
    // 可用区域
    final availableWidth = width - (padding * 2);
    final availableHeight = height - (padding * 2);

    // 估算每行字符数（中文字符）
    final charsPerLine = (availableWidth / (fontSize * 0.6)).floor();

    // 估算行数
    final linesPerPage = (availableHeight / (fontSize * lineHeight)).floor();

    // 每页字符数，至少 100 个
    return (charsPerLine * linesPerPage).clamp(100, 5000);
  }

  /// 分页内容
  List<String> _paginateContent(String content, int charsPerPage) {
    if (content.isEmpty) return [];

    final pages = <String>[];
    final totalChars = content.length;
    var offset = 0;

    while (offset < totalChars) {
      final endOffset = (offset + charsPerPage).clamp(0, totalChars);

      // 尝试在段落或句子边界处断页
      var actualEndOffset = endOffset;
      if (endOffset < totalChars) {
        // 查找最近的段落结束符
        final searchRange = content.substring(
          (endOffset - 100).clamp(0, totalChars),
          endOffset,
        );
        final lastNewline = searchRange.lastIndexOf('\n');
        if (lastNewline != -1) {
          actualEndOffset = (endOffset - 100) + lastNewline + 1;
        }
      }

      final pageContent = content.substring(offset, actualEndOffset);
      pages.add(pageContent);

      offset = actualEndOffset;
    }

    // 至少有一页
    if (pages.isEmpty) {
      pages.add(content);
    }

    return pages;
  }

  Color _getTextColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return Colors.grey[300]!;
      case ThemeMode.light:
      default:
        return Colors.black87;
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

  Future<void> _loadChapterContent(
    ChapterContentService contentService,
    Signal<String> content,
    Signal<bool> isLoading,
    Signal<String?> error,
    Signal<int> totalPages,
  ) async {
    try {
      isLoading.value = true;
      error.value = null;

      // 从服务加载章节内容
      final contentText = await contentService.loadChapterContent(
        bookId,
        chapterId,
      );

      content.value = contentText;

      // 估算页数（简化实现，实际应该使用 TextPainter）
      const int charsPerPage = 2000;
      final estimatedPages = (contentText.length / charsPerPage).ceil();
      totalPages.value = estimatedPages.clamp(1, 100);
    } catch (e) {
      error.value = '加载失败：$e';
      totalPages.value = 1;
    } finally {
      isLoading.value = false;
    }
  }
}
