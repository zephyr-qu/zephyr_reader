import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/rendering/block_page_content.dart';
import 'package:zephyr_reader/features/reader/rendering/highlight_painter.dart';

import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';

import 'package:zephyr_reader/features/reader/rendering/paginated_page_viewport.dart';
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
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text('分页数据加载失败', style: Theme.of(context).textTheme.titleMedium),
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
      Logging.warning(
        '[Renderer] _buildPageTurnShell: descriptors null/empty → fallback',
      );
      return _buildFallbackPagination(context);
    }

    Logging.info(
      '[Render] pageTurnShell descriptors=${descriptors.length} logicalIdx=${pageIndex.clamp(0, descriptors.length - 1)}',
    );
    // 打印每页内容量（从 descriptors 反推）
    for (var i = 0; i < descriptors.length && i < 8; i++) {
      final d = descriptors[i];
      Logging.info(
        '[PageContent] page=$i start=${d.startOffset} end=${d.endOffset}'
        ' chars=${d.endOffset - d.startOffset}',
      );
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
    List<PackedPage> descriptors,
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
  /// 分页模式使用 Flutter 分页产出的 plain text 文本流。
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

  /// 下一章虚拟页：staging 命中渲染预加载内容，miss 显示当前章末页 hold 帧。
  Widget _buildCrossChapterPage(BuildContext context, int virtualIndex) {
    final staging = dataSource.nextChapterStaging;
    final stagingReady =
        staging != null && staging.chapterIndex == chapterId + 1;
    if (stagingReady) {
      Logging.info(
        '[ChapterTransition] renderCrossChapter staging_ready=true'
        ' chapter=${staging.chapterIndex} virtualIndex=$virtualIndex',
      );
      final startOffset = staging.descriptors.isNotEmpty
          ? staging.descriptors[0].startOffset
          : 0;
      return _buildStagingPageFromStaging(context, staging, startOffset);
    }
    // ADR-012: staging miss → hold 帧（当前章末页），不展示 spinner
    Logging.info(
      '[Timing] cross-chapter render: staging_ready=false virtualIndex=$virtualIndex → hold frame',
    );
    return _buildHoldFrame(context, isFirstPage: false);
  }

  /// 跨章 staging 页：plain 或 block 预渲染。
  Widget _buildStagingPageFromStaging(
    BuildContext context,
    NextChapterStaging staging,
    int startOffset,
  ) {
    final blocks = staging.anchorPageBlocks;
    final bookId = staging.bookId;
    if (blocks == null || bookId == null || bookId.isEmpty) {
      // ADR-012: incomplete staging → hold frame, not spinner
      return _buildHoldFrame(context, isFirstPage: true);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return buildBlockPageContent(
          context: context,
          blocks: blocks,
          startOffset: startOffset,
          epubFilePath: dataSource.sessionFilePath ?? '',
          config: config,
          highlights: highlights,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
          maxContentWidth: constraints.maxWidth,
        );
      },
    );
  }

  /// 跨章 staging 页：plain 文本预渲染。
  Widget _buildStagingPlainPageContent(
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

  /// 上一章虚拟页：staging 命中渲染预加载内容，miss 显示当前章首页 hold 帧。
  Widget _buildPreviousChapterPage(BuildContext context) {
    final staging = dataSource.prevChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId - 1) {
      final lastIdx = staging.descriptors.length - 1;
      final startOffset = lastIdx >= 0
          ? staging.descriptors[lastIdx].startOffset
          : 0;
      return _buildStagingPageFromStaging(context, staging, startOffset);
    }
    // ADR-012: staging miss → hold 帧（当前章首页），不展示 spinner
    return _buildHoldFrame(context, isFirstPage: true);
  }

  /// ADR-012: staging miss 时显示当前章首/末页 hold 帧，替代 spinner。
  Widget _buildHoldFrame(BuildContext context, {required bool isFirstPage}) {
    final descriptors = dataSource.descriptors;
    if (descriptors == null || descriptors.isEmpty) {
      return _buildPageSkeleton();
    }
    if (isFirstPage) {
      return _buildPageContent(context, 0, descriptors[0].startOffset);
    }
    final lastIdx = descriptors.length - 1;
    return _buildPageContent(
      context,
      lastIdx,
      descriptors[lastIdx].startOffset,
    );
  }

  void _handlePageChanged(List<PackedPage> descriptors, int index) {
    // _handlePageChanged 每翻页触发一次
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

  int _extendedPageCount(List<PackedPage> descriptors) {
    // Prev virtual page always included (hasPreviousChapter flag is static);
    // hold frame in _buildPreviousChapterPage covers the staging-miss visual.
    final prevOffset = hasPreviousChapter ? 1 : 0;
    return descriptors.length + (_stagingReadyForNext() ? 1 : 0) + prevOffset;
  }

  @override
  Widget build(BuildContext context) {
    Logging.info(
      '[Render] build chapter=$chapterId page=$pageIndex mode=${readingMode.name}'
      ' descCount=${dataSource.descriptors?.length ?? 0}',
    );

    if (usesPageCurlSkin(mode: readingMode, skin: paginationSkin)) {
      return _buildPageTurnShell(context);
    }
    final descriptors = dataSource.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      // 打印每页内容量（从 descriptors 反推）
      for (var i = 0; i < descriptors.length && i < 8; i++) {
        final d = descriptors[i];
        Logging.info(
          '[PageContent] page=$i start=${d.startOffset} end=${d.endOffset}'
          ' chars=${d.endOffset - d.startOffset}',
        );
      }
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
        final bodyHeight = (constraints.maxHeight - 2 * vPad).clamp(
          0.0,
          constraints.maxHeight,
        );
        Logging.info(
          '[PageRender] stagingPage maxH_dp=${constraints.maxHeight.toStringAsFixed(1)}'
          ' vPad=$vPad bodyHeight_dp=${bodyHeight.toStringAsFixed(1)}',
        );
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: config.pageMargin,
            vertical: vPad,
          ),
          child: PaginatedPageViewport(
            maxHeight: bodyHeight,
            maxWidth: constraints.maxWidth,
            child: SelectableText.rich(
              paintedSpan,
              strutStyle: strutStyle,
              textAlign: config.textAlign,
              textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
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
      },
    ),
  );
}

/// ADR-012: page cache miss 骨架占位，替代 spinner。
/// [ensureWindow] 已在调用方通过 postFrameCallback 触发；
/// 当 [ReaderRenderDataSource.preloadGeneration] 变化时 AnimatedBuilder 重建本 widget。
Widget _buildPageSkeleton() {
  return Container(
    color: Colors.grey.withValues(alpha: 0.03),
    child: const Center(child: SizedBox.shrink()),
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
  final blocks = dataSource.pageBlocks(pageIndex);
  if (blocks == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logging.info(
        '[Renderer] buildBlockPageContent MISS page=$pageIndex → skeleton + ensureWindow',
      );
      dataSource.ensureWindow(pageIndex);
    });
    return _buildPageSkeleton();
  }
  final filePath = dataSource.sessionFilePath;
  if (filePath == null || filePath.isEmpty) {
    return _buildPageSkeleton();
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      return buildBlockPageContent(
        context: context,
        blocks: blocks,
        startOffset: startOffset,
        epubFilePath: filePath,
        config: config,
        highlights: highlights,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
        maxContentWidth: constraints.maxWidth,
      );
    },
  );
}
