import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'highlight_painter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'reader_render_config.dart';
import 'find_render_box.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 分页模式渲染器。
///
/// 以左右分页形式展示书籍内容，支持翻页动画和高亮显示。
class PaginatedModeRenderer extends StatelessWidget {
  final ReaderRenderConfig config;
  final PageController pageController;
  final ReaderRenderDataSource dataSource;
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final String content;
  final List<Note> highlights;
  final ReadingMode readingMode;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final WritingDirection writingDirection;
  final void Function(Offset?)? onSelectionGlobalPosition;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPositionChanged;
  final bool hasNextChapter;
  final bool hasPreviousChapter;
  final VoidCallback? onReachEnd;
  final VoidCallback? onReachStart;
  const PaginatedModeRenderer({
    super.key,
    required this.config,
    required this.pageController,
    required this.dataSource,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.content,
    required this.highlights,
    required this.readingMode,
    this.onHighlightTap,
    this.onSelectionChanged,
    this.onSelectionGlobalPosition,
    this.onPageChanged,
    this.onPositionChanged,
    this.hasNextChapter = false,
    this.hasPreviousChapter = false,
    this.onReachEnd,
    this.onReachStart,
    this.writingDirection = WritingDirection.horizontal,
  });

  void _reportSelectionPosition(BuildContext context, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionGlobalPosition?.call(null);
      return;
    }
    final box = findRenderBox(context);
    if (box == null || !box.hasSize || !box.attached) return;
    onSelectionGlobalPosition?.call(box.localToGlobal(Offset.zero));
  }

  void _onSelection(
    TextSelection sel,
    String paragraphText,
    int offset,
    BuildContext context,
  ) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionChanged?.call('', 0, 0);
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final text = paragraphText.substring(start, end);
    onSelectionChanged?.call(text, offset + start, offset + end);
    _reportSelectionPosition(context, sel);
  }


  /// Fallback: 无分页数据时显示错误提示，而非静默近似分页。
  Widget _buildFallbackPagination(BuildContext context) {
    Logging.warning('[Renderer] _buildFallbackPagination: no pagination data');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
              color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              '分页数据加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '无法为当前章节创建分页，请返回书架重试。',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTurn(BuildContext context) {
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      final index = pageIndex.clamp(0, descriptors.length - 1);
      Logging.debug('[Renderer] _buildPageTurn: page=$index/${descriptors.length}');
      return _buildPageContent(context, index, descriptors[index].startOffset);
    }
    Logging.warning('[Renderer] _buildPageTurn: descriptors null/empty → fallback');
    return _buildFallbackPagination(context);
  }

  /// 构建页面内容组件（描述符模式）。
  /// 如果内容未缓存（null），显示占位符。
  ///
  /// 分页模式始终使用 Rust [PageStreamer] 按行切分的 plain text。
  /// 不使用 rich 段落索引渲染：段落常跨多页，按 RichParagraph 整段
  /// 切片会在相邻页重复显示同一段落。
  Widget _buildPageContent(
    BuildContext context,
    int pageIndex,
    int startOffset,
  ) {
    final pageContent = dataSource.pageContent(pageIndex);
    if (pageContent == null) {
      Logging.info('[Renderer] _buildPageContent MISS page=$pageIndex → spinner + ensureWindow');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dataSource.ensureWindow(pageIndex);
      });
      return const Center(child: CircularProgressIndicator());
    }
    final textStyle = config.buildTextStyle();
    final strutStyle = config.buildStrutStyle();
    final paintedSpan = HighlightPainter.paintPlain(
      pageContent,
      textStyle,
      highlights,
      onHighlightTap: onHighlightTap,
      vocabularyWords: config.effectiveVocabWords,
      contentStart: startOffset,
    );
    return _renderPageContent(
      context,
      pageContent,
      paintedSpan,
      textStyle,
      strutStyle,
      startOffset,
    );
  }

  Widget _buildPageContentVertical(
    BuildContext context,
    String pageContent,
    TextSpan paintedSpan,
    TextStyle textStyle,
    StrutStyle strutStyle,
    int startOffset,
  ) {
    final charWidth = config.fontSize * 1.2;
    final paragraphs = pageContent
        .split('\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: config.pageMargin,
          vertical: 20,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: paragraphs.map((para) {
            final painted = HighlightPainter.paintPlain(
              para,
              textStyle,
              highlights,
              onHighlightTap: onHighlightTap,
              vocabularyWords: config.effectiveVocabWords,
              contentStart: startOffset,
            );
            return Padding(
              padding: EdgeInsets.only(left: paragraphs.length > 1 ? 8 : 0),
              child: SizedBox(
                width: charWidth,
                child: SelectableText.rich(
                  painted,
                  style: textStyle,
                  strutStyle: strutStyle,
                  textAlign: TextAlign.start,
                  onSelectionChanged: (sel, cause) =>
                      _onSelection(sel, para, startOffset, context),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 根据书写方向渲染页面内容（水平或竖排）
  Widget _renderPageContent(
    BuildContext context,
    String pageContent,
    TextSpan paintedSpan,
    TextStyle textStyle,
    StrutStyle strutStyle,
    int startOffset,
  ) {
    if (writingDirection == WritingDirection.vertical) {
      return _buildPageContentVertical(
        context,
        pageContent,
        paintedSpan,
        textStyle,
        strutStyle,
        startOffset,
      );
    }
    final vPad = ReaderRenderConfig.pageContentVerticalPadding;
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: config.pageMargin,
          vertical: vPad,
        ),
        child: ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            child: SelectableText.rich(
              paintedSpan,
              strutStyle: strutStyle,
              textAlign: config.textAlign,
              onSelectionChanged: (sel, cause) =>
                  _onSelection(sel, pageContent, startOffset, context),
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCrossChapterPage(BuildContext context, int virtualIndex) {
    final staging = dataSource.nextChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId + 1) {
      Logging.debug('[Renderer] _buildCrossChapterPage HIT: chapter=${staging.chapterIndex} virtualIndex=$virtualIndex');
      dataSource.warmPageCache(virtualIndex, staging.firstPageContent);
      final startOffset = staging.descriptors.isNotEmpty
          ? staging.descriptors[0].startOffset
          : 0;
      return _buildPageContent(context, virtualIndex, startOffset);
    }
    Logging.debug('[Renderer] _buildCrossChapterPage MISS: virtualIndex=$virtualIndex');
    return Container(color: config.backgroundColor);
  }

  Widget _buildPreviousChapterPage(BuildContext context) {
    // Phase 3 增加 prevChapterStaging 渲染
    return Container(color: config.backgroundColor);
  }

  void _handlePageChanged(List<PageDescriptor> descriptors, int index) {
    Logging.debug('[Renderer] _handlePageChanged: virtualIndex=$index');
    // 向后虚拟页 → onReachStart
    if (index == 0 && hasPreviousChapter) {
      onReachStart?.call();
      return;
    }
    final realIndex = hasPreviousChapter ? index - 1 : index;
    if (realIndex < 0) {
      onReachStart?.call();
      return;
    }
    if (realIndex >= descriptors.length) {
      onReachEnd?.call();
      return;
    }
    onPageChanged?.call(realIndex);
    onPositionChanged?.call(descriptors[realIndex].startOffset);
  }

  bool _stagingReadyForNext() {
    if (!hasNextChapter) return false;
    final staging = dataSource.nextChapterStaging;
    return staging != null && staging.chapterIndex == chapterId + 1;
  }

  int _extendedPageCount(List<PageDescriptor> descriptors) {
    final offset = hasPreviousChapter ? 1 : 0;
    return descriptors.length + (_stagingReadyForNext() ? 1 : 0) + offset;
  }
  @override
  Widget build(BuildContext context) {
    if (readingMode == ReadingMode.pageTurn) {
      return _buildPageTurn(context);
    }
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      return AnimatedBuilder(
        animation: dataSource.preloadGeneration,
        builder: (context, _) {
          return PageView.builder(
            controller: pageController,
            physics: adaptiveScrollPhysics(context),
            itemCount: _extendedPageCount(descriptors),
            onPageChanged: (index) => _handlePageChanged(descriptors, index),
            itemBuilder: (context, index) {
              if (hasPreviousChapter && index == 0) {
                return _buildPreviousChapterPage(context);
              }
              final realIndex = hasPreviousChapter ? index - 1 : index;
              if (realIndex >= descriptors.length) {
                return _buildCrossChapterPage(context, index);
              }
              return _buildPageContent(
                context,
                realIndex,
                descriptors[realIndex].startOffset,
              );
            },
          );
        },
      );
    }
    Logging.warning('[Renderer] build: descriptors null/empty → fallback');
    return _buildFallbackPagination(context);
  }
}

// ── Standalone page builder (shared with PageCurlWidget) ──

void _reportSelectionPositionStandalone(
  BuildContext context,
  void Function(Offset?)? onSelectionGlobalPosition,
) {
  if (onSelectionGlobalPosition == null) return;
  final box = findRenderBox(context);
  if (box == null || !box.hasSize || !box.attached) return;
  onSelectionGlobalPosition(box.localToGlobal(Offset.zero));
}

void _handlePageContentSelection(
  TextSelection sel,
  String paragraphText,
  int offset,
  BuildContext context,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
) {
  if (!sel.isValid || sel.isCollapsed) {
    onSelectionChanged?.call('', 0, 0);
    return;
  }
  final start = sel.start;
  final end = sel.end;
  final text = paragraphText.substring(start, end);
  onSelectionChanged?.call(text, offset + start, offset + end);
  _reportSelectionPositionStandalone(context, onSelectionGlobalPosition);
}

Widget _buildPageContentVerticalStandalone(
  BuildContext context,
  String pageContent,
  TextStyle textStyle,
  StrutStyle strutStyle,
  int startOffset,
  ReaderRenderConfig config,
  List<Note> highlights,
  void Function(Note)? onHighlightTap,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
) {
  final charWidth = config.fontSize * 1.2;
  final paragraphs = pageContent
      .split('\n')
      .where((p) => p.trim().isNotEmpty)
      .toList();

  return Directionality(
    textDirection: TextDirection.rtl,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: paragraphs.map((para) {
          final painted = HighlightPainter.paintPlain(
            para,
            textStyle,
            highlights,
            onHighlightTap: onHighlightTap,
            vocabularyWords: config.effectiveVocabWords,
            contentStart: startOffset,
          );
          return Padding(
            padding: EdgeInsets.only(left: paragraphs.length > 1 ? 8 : 0),
            child: SizedBox(
              width: charWidth,
              child: SelectableText.rich(
                painted,
                style: textStyle,
                strutStyle: strutStyle,
                textAlign: TextAlign.start,
                onSelectionChanged: (sel, cause) => _handlePageContentSelection(
                  sel,
                  para,
                  startOffset,
                  context,
                  onSelectionChanged,
                  onSelectionGlobalPosition,
                ),
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

/// Builds a single page widget for a given page index.
/// Used by [PageCurlWidget] to render page content on demand.
Widget buildSinglePageContent({
  required BuildContext context,
  required int pageIndex,
  required int startOffset,
  required ReaderRenderDataSource dataSource,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  required WritingDirection writingDirection,
  required void Function(Note)? onHighlightTap,
  required void Function(String text, int start, int end)? onSelectionChanged,
  required void Function(Offset?)? onSelectionGlobalPosition,
}) {
  // 与 PaginatedModeRenderer._buildPageContent 相同：只用 Rust 行切分 plain text。
  final pageContent = dataSource.pageContent(pageIndex);
  if (pageContent == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logging.info('[Renderer] buildSinglePageContent MISS page=$pageIndex → spinner + ensureWindow');
      dataSource.ensureWindow(pageIndex);
    });
    return const Center(child: CircularProgressIndicator());
  }
  final textStyle = config.buildTextStyle();
  final strutStyle = config.buildStrutStyle();
  final paintedSpan = HighlightPainter.paintPlain(
    pageContent,
    textStyle,
    highlights,
    onHighlightTap: onHighlightTap,
    vocabularyWords: config.effectiveVocabWords,
    contentStart: startOffset,
  );

  if (writingDirection == WritingDirection.vertical) {
    return _buildPageContentVerticalStandalone(
      context,
      pageContent,
      textStyle,
      strutStyle,
      startOffset,
      config,
      highlights,
      onHighlightTap,
      onSelectionChanged,
      onSelectionGlobalPosition,
    );
  }

  return RepaintBoundary(
    child: Padding(
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: ReaderRenderConfig.pageContentVerticalPadding,
      ),
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          child: SelectableText.rich(
            paintedSpan,
            strutStyle: strutStyle,
            textAlign: config.textAlign,
            onSelectionChanged: (sel, cause) => _handlePageContentSelection(
              sel,
              pageContent,
              startOffset,
              context,
              onSelectionChanged,
              onSelectionGlobalPosition,
            ),
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
