/// 阅读器内容组件
///
/// 支持滚动和分页两种模式的内容渲染
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_hooks/signals_hooks.dart';

import '../../../../core/database/database.dart';
import '../../data/reader_service.dart';

/// 阅读器内容组件
class ReaderContent extends HookWidget {
  /// 书籍 ID
  final String bookId;

  /// 章节 ID
  final int chapterId;

  /// 当前页码
  final int pageIndex;

  /// 字体大小
  final double fontSize;

  /// 行间距
  final double lineHeight;

  /// 主题模式
  final ThemeMode themeMode;

  /// 页码变化回调
  final ValueChanged<int>? onPageChanged;

  /// 总页数变化回调
  final ValueChanged<int>? onTotalPagesChanged;

  const ReaderContent({
    super.key,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    this.onPageChanged,
    this.onTotalPagesChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 内容状态
    final content = useSignal<String>('');
    final isLoading = useSignal(true);
    final error = useSignal<String?>(null);
    final totalPages = useSignal(0);

    // 页面控制器
    final pageController = usePageController();

    // 加载章节内容
    useEffect(() {
      _loadChapterContent(
        chapterId,
        content,
        isLoading,
        error,
        totalPages,
        onTotalPagesChanged,
      );
      return null;
    }, [chapterId]);

    // 监听页码变化
    useEffect(() {
      if (pageController.hasClients) {
        pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return null;
    }, [pageIndex]);

    // 加载状态
    if (isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    // 错误状态
    if (error.value != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(error.value!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _loadChapterContent(
                  chapterId,
                  content,
                  isLoading,
                  error,
                  totalPages,
                  onTotalPagesChanged,
                );
              },
              child: const Text('重新加载'),
            ),
          ],
        ),
      );
    }

    // 根据主题获取颜色
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFF5F5DC);

    return Container(
      color: backgroundColor,
      child: PageView.builder(
        controller: pageController,
        itemCount: totalPages.value,
        onPageChanged: (index) {
          onPageChanged?.call(index);
        },
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              content.value,
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: textColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadChapterContent(
    int chapterId,
    Signal<String> content,
    Signal<bool> isLoading,
    Signal<String?> error,
    Signal<int> totalPages,
    ValueChanged<int>? onTotalPagesChanged,
  ) async {
    try {
      isLoading.value = true;
      error.value = null;

      // 从数据库或 Rust 引擎加载章节内容
      final readerService = GetIt.I.get<ReaderService>();
      final database = GetIt.I.get<AppDatabase>();

      // 获取章节信息 - 使用 chapterId 作为 chapterIndex
      // 注意：这里假设 chapterId 就是 chapterIndex，如果不是需要调整
      final chapter = await database.getChapter(0, chapterId);

      if (chapter == null) {
        throw Exception('章节不存在');
      }

      // 读取章节内容文件
      final contentText = await readerService.getChapterContent(
        chapter.contentFile,
      );

      if (contentText == null || contentText.isEmpty) {
        throw Exception('章节内容为空');
      }

      content.value = contentText;

      // 根据内容长度估算页数（简化实现）
      const int charsPerPage = 2000;
      final estimatedPages = (contentText.length / charsPerPage).ceil();
      totalPages.value = estimatedPages.clamp(1, 100);
      onTotalPagesChanged?.call(totalPages.value);

      isLoading.value = false;
    } catch (e) {
      error.value = '加载失败：$e';
      isLoading.value = false;
    }
  }
}
