/// 阅读器内容组�?///
/// 使用 Rust 引擎的分页功能渲染章节内�?
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/src/rust/api.dart' as rust_api;
import 'package:zephyr_reader/src/rust/ffi/types.dart';
import 'package:zephyr_reader/src/rust/stream/page_stream.dart';

/// 阅读器内容组�?
class ReaderContent extends HookWidget {
  /// 书籍 ID
  final String bookId;

  /// 章节 ID
  final int chapterId;

  /// 当前页码
  final int pageIndex;

  /// 字体大小
  final double fontSize;

  /// 行间�?  final double lineHeight;

  /// 主题模式
  final ThemeMode themeMode;

  /// 页面变化回调
  final ValueChanged<int>? onPageChanged;

  /// 总页数变化回�?
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
    final content = useState<String>('');
    final totalPages = useState(0);
    final isLoading = useState(true);
    final error = useState<String?>(null);
    final pageStreamer = useState<PageStreamer?>(null);

    // 加载章节内容
    useEffect(() {
      _loadChapterContent(content, totalPages, isLoading, error, pageStreamer);
      return null;
    }, [bookId, chapterId]);

    // 监听页面变化
    useEffect(() {
      onPageChanged?.call(pageIndex);
      return null;
    }, [pageIndex]);

    return Stack(
      children: [
        if (isLoading.value)
          const Center(child: CircularProgressIndicator())
        else if (error.value != null)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('加载失败�?{error.value}'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => _loadChapterContent(
                    content,
                    totalPages,
                    isLoading,
                    error,
                    pageStreamer,
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          )
        else if (content.value.isEmpty)
          const Center(child: Text('章节内容为空'))
        else
          _buildPageContent(
            content.value,
            themeMode,
            fontSize,
            lineHeight,
            pageStreamer.value,
            totalPages.value,
          ),
      ],
    );
  }

  Future<void> _loadChapterContent(
    ValueNotifier<String> content,
    ValueNotifier<int> totalPages,
    ValueNotifier<bool> isLoading,
    ValueNotifier<String?> error,
    ValueNotifier<PageStreamer?> pageStreamer,
  ) async {
    try {
      isLoading.value = true;
      error.value = null;

      // 从数据库或文件加载章节内�?      // 这里假设章节内容存储在文件中
      final chapterContent = await _loadChapterFromFile();

      if (chapterContent == null || chapterContent.isEmpty) {
        content.value = '';
        isLoading.value = false;
        return;
      }

      // 使用 Rust 引擎进行分页
      final config = TypesetConfig(
        pageWidth: 1080, // 假设标准手机屏幕宽度
        pageHeight: 1920,
        fontSize: fontSize.toInt(),
        lineSpacing: lineHeight,
        letterSpacing: 0,
        paragraphSpacing: 1,
        firstLineIndent: 2,
        language: LanguageType.auto,
        enableHyphenation: false,
        hyphenationLanguage: null,
      );

      try {
        pageStreamer.value = RustLib.instance.api.createPageStreamer(
          content: chapterContent,
          config: config,
        );

        totalPages.value = pageStreamer.value!.totalPages;
        onTotalPagesChanged?.call(totalPages.value);

        // 获取当前页内�?        pageStreamer.value!.currentPage = pageIndex;
        content.value = pageStreamer.value!.currentContent;
      } catch (e) {
        // 如果分页失败，使用原始内�?        debugPrint('Rust 分页失败，使用原始内容：$e');
        content.value = chapterContent;
        totalPages.value = 1;
        onTotalPagesChanged?.call(1);
      }

      isLoading.value = false;
    } catch (e) {
      error.value = e.toString();
      isLoading.value = false;
      debugPrint('加载章节内容失败�?e');
    }
  }

  Future<String?> _loadChapterFromFile() async {
    // 从数据库或文件加载章节内�?    // TODO: 实现实际的数据库加载逻辑
    // 这里返回示例数据
    return '''
这是�?$chapterId 章的示例内容�?
实际实现中，这里会显示从 Rust 引擎加载的真实章节内容�?Rust 引擎会根据字体大小、行间距等配置自动分页�?
功能说明�?1. 支持上下滚动和左右翻页两种模�?2. 自动保存阅读进度
3. 支持章节跳转
4. 支持书签功能
5. 可调节字体大小、行间距�?
点击屏幕中央可以显示/隐藏工具栏�?使用底部工具栏可以翻页或切换章节�?''';
  }

  Widget _buildPageContent(
    String content,
    ThemeMode themeMode,
    double fontSize,
    double lineHeight,
    PageStreamer? pageStreamer,
    int totalPages,
  ) {
    if (pageStreamer != null && totalPages > 1) {
      // 使用 Rust 分页的翻页模�?
      //
         return PageView.builder(
        itemCount: totalPages,
        controller: PageController(initialPage: pageIndex),
        onPageChanged: (index) {
          pageStreamer.currentPage = index;
          onPageChanged?.call(index);
        },
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              pageStreamer.getPageContent(index),
              style: TextStyle(
                fontSize: fontSize,
                height: lineHeight,
                color: themeMode == ThemeMode.dark
                    ? Colors.grey[300]
                    : Colors.black87,
              ),
            ),
          );
        },
      );
    } else {
      // 单页滚动模式
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          content,
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
  }
}
