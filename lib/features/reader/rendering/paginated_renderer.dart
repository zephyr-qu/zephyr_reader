import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'highlight_painter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'reader_render_config.dart';
import 'find_render_box.dart';

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

  int _estimateCharsPerPage() {
    final width = 400.0;
    final height = 600.0;
    final availableWidth = width - 32;
    final availableHeight = height - 32;
    final charsPerLine = (availableWidth / config.fontSize).floor();
    final linesPerPage =
        (availableHeight / (config.fontSize * config.lineHeight)).floor();
    return (charsPerLine * linesPerPage).clamp(100, 5000);
  }

  List<String> _paginateContent(String text, int charsPerPage) {
    if (text.isEmpty) return [];
    final pages = <String>[];
    final totalChars = text.length;
    var offset = 0;
    while (offset < totalChars) {
      final endOffset = (offset + charsPerPage).clamp(0, totalChars);
      var actualEndOffset = endOffset;
      if (endOffset < totalChars) {
        final searchRange = text.substring(
          (endOffset - 100).clamp(0, totalChars),
          endOffset,
        );
        final lastNewline = searchRange.lastIndexOf('\n');
        if (lastNewline != -1) {
          actualEndOffset = (endOffset - 100) + lastNewline + 1;
        }
      }
      pages.add(text.substring(offset, actualEndOffset));
      offset = actualEndOffset;
    }
    if (pages.isEmpty) pages.add(text);
    return pages;
  }

  int _findFallbackPageStart(List<String> pages, int targetIndex) {
    var offset = 0;
    for (int i = 0; i < targetIndex && i < pages.length; i++) {
      offset += pages[i].length;
    }
    return offset;
  }

  Widget _buildFallbackPagination(BuildContext context) {
    final charsPerPage = _estimateCharsPerPage();
    final pages = _paginateContent(content, charsPerPage);
    if (pages.isEmpty) return const Center(child: Text('内容为空'));

    var accOffset = 0;
    return PageView.builder(
      controller: pageController,
      physics: adaptiveScrollPhysics(context),
      itemCount: pages.length,
      onPageChanged: (index) {
        onPageChanged?.call(index);
        onPositionChanged?.call(_findFallbackPageStart(pages, index));
      },
      itemBuilder: (context, index) {
        final pageContent = pages[index];
        final pageStart = accOffset;
        accOffset += pageContent.length;
        final textStyle = config.buildTextStyle();
        final strutStyle = config.buildStrutStyle();
        final painted = HighlightPainter.paintPlain(
          pageContent,
          textStyle,
          highlights,
          onHighlightTap: onHighlightTap,
          vocabularyWords: config.effectiveVocabWords,
        );
        return _renderPageContent(
          context,
          pageContent,
          painted,
          textStyle,
          strutStyle,
          pageStart,
        );
      },
    );
  }

  Widget _buildPageTurn(BuildContext context) {
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      final index = pageIndex.clamp(0, descriptors.length - 1);
      return _buildPageContent(context, index, descriptors[index].startOffset);
    }
    return _buildFallbackPagination(context);
  }

  /// 构建页面内容组件（描述符模式）。
  /// 如果内容未缓存（null），显示占位符。
  Widget _buildPageContent(
    BuildContext context,
    int pageIndex,
    int startOffset,
  ) {
    final pageContent = dataSource.pageContent(pageIndex);
    if (pageContent == null) {
      return const SizedBox(width: double.infinity, height: 600);
    }
    final textStyle = config.buildTextStyle();
    final strutStyle = config.buildStrutStyle();
    final paintedSpan = HighlightPainter.paintPlain(
      pageContent,
      textStyle,
      highlights,
      onHighlightTap: onHighlightTap,
      vocabularyWords: config.effectiveVocabWords,
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
    return RepaintBoundary(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: config.pageMargin,
          vertical: 20,
        ),
        child: SelectableText.rich(
          paintedSpan,
          strutStyle: strutStyle,
          textAlign: config.textAlign,
          onSelectionChanged: (sel, cause) =>
              _onSelection(sel, pageContent, startOffset, context),
          contextMenuBuilder: (_, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (readingMode == ReadingMode.pageTurn) {
      return _buildPageTurn(context);
    }
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      return PageView.builder(
        controller: pageController,
        physics: adaptiveScrollPhysics(context),
        itemCount: descriptors.length,
        onPageChanged: (index) {
          onPageChanged?.call(index);
          onPositionChanged?.call(descriptors[index].startOffset);
        },
        itemBuilder: (context, index) =>
            _buildPageContent(context, index, descriptors[index].startOffset),
      );
    }
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
  final pageContent = dataSource.pageContent(pageIndex);
  if (pageContent == null) {
    return Container(color: config.backgroundColor);
  }
  final textStyle = config.buildTextStyle();
  final strutStyle = config.buildStrutStyle();
  final paintedSpan = HighlightPainter.paintPlain(
    pageContent,
    textStyle,
    highlights,
    onHighlightTap: onHighlightTap,
    vocabularyWords: config.effectiveVocabWords,
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
    child: SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
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
  );
}
