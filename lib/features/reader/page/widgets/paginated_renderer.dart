import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/domain/services/highlight_painter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'reader_render_config.dart';

class PaginatedModeRenderer extends StatelessWidget {
  final ReaderRenderConfig config;
  final PageController pageController;
  final ReaderRepository repo;
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final String content;
  final List<Note> highlights;
  final ReadingMode readingMode;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final void Function(Offset?)? onSelectionGlobalPosition;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onPositionChanged;

  const PaginatedModeRenderer({
    super.key,
    required this.config,
    required this.pageController,
    required this.repo,
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
  });

  void _reportSelectionPosition(BuildContext context, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionGlobalPosition?.call(null);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
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
          searchQuery: config.searchQuery,
          searchMatchHighlight: config.searchMatchHighlight,
          vocabularyWords: config.effectiveVocabWords,
        );
        return RepaintBoundary(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: config.pageMargin,
              vertical: 20,
            ),
            child: SelectableText.rich(
              painted,
              strutStyle: strutStyle,
              textAlign: TextAlign.justify,
              onSelectionChanged: (sel, cause) =>
                  _onSelection(sel, pageContent, pageStart, context),
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageTurn(BuildContext context) {
    final cachedPages = repo.currentPages;
    if (cachedPages != null && cachedPages.isNotEmpty) {
      final index = pageIndex.clamp(0, cachedPages.length - 1);
      final page = cachedPages[index];
      final textStyle = config.buildTextStyle();
      final strutStyle = config.buildStrutStyle();
      final paintedSpan = page.richContent != null
          ? HighlightPainter.paintRich(
              page.richContent!,
              page.startOffset,
              highlights,
              onHighlightTap: onHighlightTap,
              searchQuery: config.searchQuery,
              searchMatchHighlight: config.searchMatchHighlight,
              vocabularyWords: config.effectiveVocabWords,
            )
          : HighlightPainter.paintPlain(
              page.content,
              textStyle,
              highlights,
              onHighlightTap: onHighlightTap,
              searchQuery: config.searchQuery,
              searchMatchHighlight: config.searchMatchHighlight,
              vocabularyWords: config.effectiveVocabWords,
            );
      return RepaintBoundary(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: config.pageMargin,
            vertical: 20,
          ),
          child: SelectableText.rich(
            page.richContent != null
                ? TextSpan(style: textStyle, children: [paintedSpan])
                : paintedSpan,
            strutStyle: strutStyle,
            textAlign: TextAlign.justify,
            onSelectionChanged: (sel, cause) =>
                _onSelection(sel, page.content, page.startOffset, context),
            contextMenuBuilder: (_, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    return _buildFallbackPagination(context);
  }

  @override
  Widget build(BuildContext context) {
    if (readingMode == ReadingMode.pageTurn) {
      return _buildPageTurn(context);
    }
    final cachedPages = repo.currentPages;
    if (cachedPages != null && cachedPages.isNotEmpty) {
      return PageView.builder(
        controller: pageController,
        physics: adaptiveScrollPhysics(context),
        itemCount: cachedPages.length,
        onPageChanged: (index) {
          onPageChanged?.call(index);
          onPositionChanged?.call(cachedPages[index].startOffset);
        },
        itemBuilder: (context, index) {
          final page = cachedPages[index];
          final textStyle = config.buildTextStyle();
          final strutStyle = config.buildStrutStyle();
          if (page.richContent != null) {
            final painted = HighlightPainter.paintRich(
              page.richContent!,
              page.startOffset,
              highlights,
              onHighlightTap: onHighlightTap,
              searchQuery: config.searchQuery,
              searchMatchHighlight: config.searchMatchHighlight,
              vocabularyWords: config.effectiveVocabWords,
            );
            return RepaintBoundary(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: config.pageMargin,
                  vertical: 20,
                ),
                child: SelectableText.rich(
                  TextSpan(style: textStyle, children: [painted]),
                  strutStyle: strutStyle,
                  textAlign: TextAlign.justify,
                  onSelectionChanged: (sel, cause) => _onSelection(
                    sel,
                    page.content,
                    page.startOffset,
                    context,
                  ),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            );
          }
          final paintedSpan = HighlightPainter.paintPlain(
            page.content,
            textStyle,
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: config.searchQuery,
            searchMatchHighlight: config.searchMatchHighlight,
            vocabularyWords: config.effectiveVocabWords,
          );
          return RepaintBoundary(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: config.pageMargin,
                vertical: 20,
              ),
              child: SelectableText.rich(
                paintedSpan,
                strutStyle: strutStyle,
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) =>
                    _onSelection(sel, page.content, page.startOffset, context),
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      );
    }
    return _buildFallbackPagination(context);
  }
}
