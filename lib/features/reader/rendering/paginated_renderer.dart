import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'highlight_painter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'reader_render_config.dart';
import 'find_render_box.dart';
import 'package:zephyr_reader/features/reader/data/pagination_viewport_index.dart';
import 'package:zephyr_reader/features/reader/rendering/page_turn_shell.dart';
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
  final PaginationSkin paginationSkin;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
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
    this.paginationSkin = PaginationSkin.slide,
    this.onHighlightTap,
    this.onSelectionChanged,
    this.onSelectionGlobalPosition,
    this.onPageChanged,
    this.onPositionChanged,
    this.hasNextChapter = false,
    this.hasPreviousChapter = false,
    this.onReachEnd,
    this.onReachStart,
  });

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

  Widget _buildPageTurnShell(BuildContext context) {
    final descriptors = dataSource.descriptors;
    if (descriptors == null || descriptors.isEmpty) {
      Logging.warning('[Renderer] _buildPageTurnShell: descriptors null/empty → fallback');
      return _buildFallbackPagination(context);
    }

    return AnimatedBuilder(
      animation: dataSource.preloadGeneration,
      builder: (context, _) {
        return PageTurnShell(
          logicalPageIndex: pageIndex.clamp(0, descriptors.length - 1),
          logicalPageCount: descriptors.length,
          hasPreviousChapter: hasPreviousChapter,
          hasNextStagingPage: _stagingReadyForNext(),
          descriptors: descriptors,
          onLogicalPageChanged: (idx) => onPageChanged?.call(idx),
          onReachEnd: onReachEnd,
          onReachStart: onReachStart,
          onPositionChanged: onPositionChanged,
          pageBuilder: (physicalIdx) =>
              _buildPageTurnPhysicalPage(context, physicalIdx, descriptors),
        );
      },
    );
  }

  Widget _buildPageTurnPhysicalPage(
    BuildContext context,
    int physicalIdx,
    List<PageDescriptor> descriptors,
  ) {
    final virtualPrev = paginationVirtualPrevOffset(hasPreviousChapter);
    if (hasPreviousChapter && physicalIdx == 0) {
      return _buildPreviousChapterPage(context);
    }
    final logicalIdx = physicalIdx - virtualPrev;
    if (logicalIdx >= descriptors.length) {
      return _buildCrossChapterPage(context, physicalIdx);
    }
    return _buildPageContent(
      context,
      logicalIdx,
      descriptors[logicalIdx].startOffset,
    );
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
    return buildSinglePageContent(
      context: context,
      pageIndex: pageIndex,
      startOffset: startOffset,
      dataSource: dataSource,
      config: config,
      highlights: highlights,
      onHighlightTap: onHighlightTap,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
    );
  }

  Widget _buildCrossChapterPage(BuildContext context, int virtualIndex) {
    final staging = dataSource.nextChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId + 1) {
      Logging.debug('[Renderer] _buildCrossChapterPage HIT: chapter=${staging.chapterIndex} virtualIndex=$virtualIndex');
      final startOffset = staging.descriptors.isNotEmpty
          ? staging.descriptors[0].startOffset
          : 0;
      return _buildStagingPageContent(context, staging.firstPageContent, startOffset);
    }
    Logging.debug('[Renderer] _buildCrossChapterPage MISS: virtualIndex=$virtualIndex');
    return const Center(child: CircularProgressIndicator());
  }

  /// 跨章 staging 页：直接渲染预加载文本，不走当前章 session 页索引。
  Widget _buildStagingPageContent(
    BuildContext context,
    String pageContent,
    int startOffset,
  ) {
    return buildStagingPageContent(
      context: context,
      pageContent: pageContent,
      startOffset: startOffset,
      config: config,
      highlights: highlights,
      onHighlightTap: onHighlightTap,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
    );
  }

  Widget _buildPreviousChapterPage(BuildContext context) {
    final staging = dataSource.prevChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId - 1) {
      final lastIdx = staging.descriptors.length - 1;
      final startOffset = lastIdx >= 0
          ? staging.descriptors[lastIdx].startOffset
          : 0;
      return _buildStagingPageContent(
        context,
        staging.firstPageContent,
        startOffset,
      );
    }
    return const Center(child: CircularProgressIndicator());
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
    if (usesPageCurlSkin(mode: readingMode, skin: paginationSkin)) {
      return _buildPageTurnShell(context);
    }
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      return AnimatedBuilder(
        animation: dataSource.preloadGeneration,
        builder: (context, _) {
          return PageView.builder(
            controller: pageController,
            physics: const PageScrollPhysics(),
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

/// 跨章 staging 页：直接渲染预加载文本，不走 session 页索引。
/// 供 [PaginatedModeRenderer] 与 [PageCurlWidget] 共用。
Widget buildStagingPageContent({
  required BuildContext context,
  required String pageContent,
  required int startOffset,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  required void Function(Note)? onHighlightTap,
  required void Function(String text, int start, int end)? onSelectionChanged,
  required void Function(Offset?)? onSelectionGlobalPosition,
}) {
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

  return RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vPad = ReaderRenderConfig.pageContentVerticalPadding;
        final bodyHeight =
            (constraints.maxHeight - 2 * vPad).clamp(0.0, constraints.maxHeight);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: config.pageMargin,
            vertical: vPad,
          ),
          child: SizedBox(
            height: bodyHeight,
            width: constraints.maxWidth,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: SelectableText.rich(
                  paintedSpan,
                  strutStyle: strutStyle,
                  textAlign: config.textAlign,
                  onSelectionChanged: (sel, cause) =>
                      _handlePageContentSelection(
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
      },
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

  return RepaintBoundary(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vPad = ReaderRenderConfig.pageContentVerticalPadding;
        final bodyHeight =
            (constraints.maxHeight - 2 * vPad).clamp(0.0, constraints.maxHeight);
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: config.pageMargin,
            vertical: vPad,
          ),
          child: SizedBox(
            height: bodyHeight,
            width: constraints.maxWidth,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: SelectableText.rich(
                  paintedSpan,
                  strutStyle: strutStyle,
                  textAlign: config.textAlign,
                  onSelectionChanged: (sel, cause) =>
                      _handlePageContentSelection(
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
      },
    ),
  );
}
