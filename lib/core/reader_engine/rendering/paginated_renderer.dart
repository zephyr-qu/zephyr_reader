import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reading_mode_utils.dart';
import 'package:zephyr_reader/core/reader_engine/shared/next_chapter_staging.dart';
import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/block_page_content.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/highlight_painter.dart';

import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';

import 'package:zephyr_reader/core/utils/find_render_box.dart';
import 'reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/viewport_index.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/page_turn_shell.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 分页模式渲染器。
///
/// 以左右分页形式展示书籍内容，支持翻页动画和高亮显示。
class PaginatedModeRenderer extends StatelessWidget {
  final ReaderRenderConfig config;
  final PageController pageController;
  final ChapterContentRepository contentRepo;
  final PaginationEngine engine;
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
    required this.contentRepo,
    required this.engine,
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
    final pages = engine.session.pagePlans;
    if (pages == null) {
      return _buildPageSkeleton();
    }
    if (pages.isEmpty) {
      Logging.warning(
        '[Renderer] _buildPageTurnShell: pages null/empty → fallback',
      );
      return _buildFallbackPagination(context);
    }

    Logging.info(
      '[Render] pageTurnShell pages=${pages.length} logicalIdx=${pageIndex.clamp(0, pages.length - 1)}',
    );
    for (var i = 0; i < pages.length && i < 8; i++) {
      final d = pages[i];
      Logging.info(
        '[PageContent] page=$i start=${d.startUtf16} end=${d.endUtf16}'
        ' chars=${d.endUtf16 - d.startUtf16}',
      );
    }

    return AnimatedBuilder(
      animation: contentRepo.preloadGeneration,
      builder: (context, _) {
        return PageTurnShell(
          logicalPageIndex: pageIndex.clamp(0, pages.length - 1),
          logicalPageCount: pages.length,
          hasPreviousChapter: hasPreviousChapter,
          hasNextStagingPage: _stagingReadyForNext(),
          pagePlans: pages,
          onLogicalPageChanged: (idx) => onPageChanged?.call(idx),
          onReachEnd: onReachEnd,
          onReachStart: onReachStart,
          onPositionChanged: onPositionChanged,
          pageBuilder: (physicalIdx) =>
              _buildPageTurnPhysicalPage(context, physicalIdx, pages),
        );
      },
    );
  }

  Widget _buildPageTurnPhysicalPage(
    BuildContext context,
    int physicalIdx,
    List<PagePlan> pages,
  ) {
    final virtualPrev = paginationVirtualPrevOffset(hasPreviousChapter);
    if (hasPreviousChapter && physicalIdx == 0) {
      return _buildPreviousChapterPage(context);
    }
    final logicalIdx = physicalIdx - virtualPrev;
    if (logicalIdx >= pages.length) {
      return _buildCrossChapterPage(context, physicalIdx);
    }
    return _buildPageContent(context, logicalIdx, pages[logicalIdx].startUtf16);
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
      session: engine.session,
      config: config,
      highlights: highlights,
      onHighlightTap: onHighlightTap,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
    );
  }

  /// 下一章虚拟页：staging 命中渲染预加载内容，miss 显示当前章末页 hold 帧。
  Widget _buildCrossChapterPage(BuildContext context, int virtualIndex) {
    final staging = contentRepo.nextChapterStaging;
    final stagingReady =
        staging != null && staging.chapterIndex == chapterId + 1;
    if (stagingReady) {
      Logging.info(
        '[ChapterTransition] renderCrossChapter staging_ready=true'
        ' chapter=${staging.chapterIndex} virtualIndex=$virtualIndex',
      );
      final startOffset = staging.pagePlans.isNotEmpty
          ? staging.pagePlans[0].startUtf16
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
    final page = staging.anchorPagePlan;
    final bookId = staging.bookId;
    if (page == null || bookId == null || bookId.isEmpty) {
      // ADR-012: incomplete staging → hold frame, not spinner
      return _buildHoldFrame(context, isFirstPage: true);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final spec = staging.spec;
        return buildPagePlanContent(
          context: context,
          page: page,
          spec: spec,
          config: config,
          epubFilePath: engine.session.sessionFilePath ?? '',
          highlights: highlights,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
        );
      },
    );
  }

  /// 上一章虚拟页：staging 命中渲染预加载内容，miss 显示当前章首页 hold 帧。
  Widget _buildPreviousChapterPage(BuildContext context) {
    final staging = contentRepo.prevChapterStaging;
    if (staging != null && staging.chapterIndex == chapterId - 1) {
      final lastIdx = staging.pagePlans.length - 1;
      final startOffset = lastIdx >= 0
          ? staging.pagePlans[lastIdx].startUtf16
          : 0;
      return _buildStagingPageFromStaging(context, staging, startOffset);
    }
    // ADR-012: staging miss → hold 帧（当前章首页），不展示 spinner
    return _buildHoldFrame(context, isFirstPage: true);
  }

  Widget _buildHoldFrame(BuildContext context, {required bool isFirstPage}) {
    final pages = engine.session.pagePlans;
    if (pages == null || pages.isEmpty) {
      return _buildPageSkeleton();
    }
    if (isFirstPage) {
      return _buildPageContent(context, 0, pages[0].startUtf16);
    }
    final lastIdx = pages.length - 1;
    return _buildPageContent(context, lastIdx, pages[lastIdx].startUtf16);
  }

  void _handlePageChanged(List<PagePlan> pages, int index) {
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
    if (realIndex >= pages.length) {
      onReachEnd?.call();
      return;
    }
    onPageChanged?.call(realIndex);
    onPositionChanged?.call(pages[realIndex].startUtf16);
  }

  bool _stagingReadyForNext() {
    if (!hasNextChapter) return false;
    final staging = contentRepo.nextChapterStaging;
    return staging != null && staging.chapterIndex == chapterId + 1;
  }

  int _extendedPageCount(List<PagePlan> pages) {
    // Prev virtual page always included (hasPreviousChapter flag is static);
    // hold frame in _buildPreviousChapterPage covers the staging-miss visual.
    final prevOffset = hasPreviousChapter ? 1 : 0;
    return pages.length + (_stagingReadyForNext() ? 1 : 0) + prevOffset;
  }

  @override
  Widget build(BuildContext context) {
    final pages = engine.session.pagePlans;
    Logging.info(' pageCount=${pages?.length ?? 0}');

    if (usesPageCurlSkin(mode: readingMode, skin: paginationSkin)) {
      return _buildPageTurnShell(context);
    }
    if (pages != null && pages.isNotEmpty) {
      for (var i = 0; i < pages.length && i < 8; i++) {
        final d = pages[i];
        Logging.info(
          '[PageContent] page=$i start=${d.startUtf16} end=${d.endUtf16}'
          ' chars=${d.endUtf16 - d.startUtf16}',
        );
      }
      return AnimatedBuilder(
        animation: contentRepo.preloadGeneration,
        builder: (context, _) {
          return PageView.builder(
            controller: pageController,
            physics: const PageScrollPhysics(),
            itemCount: _extendedPageCount(pages),
            onPageChanged: (index) => _handlePageChanged(pages, index),
            itemBuilder: (context, index) {
              if (hasPreviousChapter && index == 0) {
                return _buildPreviousChapterPage(context);
              }
              final realIndex = hasPreviousChapter ? index - 1 : index;
              if (realIndex >= pages.length) {
                return _buildCrossChapterPage(context, index);
              }
              return _buildPageContent(
                context,
                realIndex,
                pages[realIndex].startUtf16,
              );
            },
          );
        },
      );
    }
    if (pages == null) {
      return _buildPageSkeleton();
    }
    Logging.warning('[Renderer] build: pages null/empty → fallback');
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
/// [ensureWindow] 已在调用方通过 postFrameCallback 触发。
/// preloadGeneration 变化时 AnimatedBuilder 重建本 widget。
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
  required PaginationSession session,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  required void Function(Note)? onHighlightTap,
  required void Function(String text, int start, int end)? onSelectionChanged,
  required void Function(Offset?)? onSelectionGlobalPosition,
}) {
  final page = session.pagePlan(pageIndex);
  if (page == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logging.info(
        '[Renderer] buildPagePlanContent MISS page=$pageIndex → skeleton + ensureWindow',
      );
      session.ensureWindow(pageIndex);
    });
    return _buildPageSkeleton();
  }
  final filePath = session.sessionFilePath;
  if (filePath == null || filePath.isEmpty) {
    return _buildPageSkeleton();
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final spec = session.layoutSnapshot!.spec;
      return buildPagePlanContent(
        context: context,
        page: page,
        spec: spec,
        config: config,
        epubFilePath: filePath,
        highlights: highlights,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
      );
    },
  );
}
