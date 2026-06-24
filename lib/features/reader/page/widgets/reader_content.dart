import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/data/pagination_viewport_index.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import '../../core/data/reader_render_data_source.dart';
import '../../core/data/scroll_chapter_segment.dart';
import '../../core/data/scroll_position_mapper.dart';

/// 阅读内容容器组件。
///
/// 根据当前阅读模式（分页/滚动/双语）选择对应渲染器展示书籍内容。
/// 集成高亮显示、翻页动画、双向滚动等阅读交互功能。
class ReaderContent extends HookWidget {
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final int totalPages;
  final ReaderRenderDataSource dataSource;
  final ReaderRenderConfig renderConfig;
  final ReadingMode readingMode;
  final PaginationSkin paginationSkin;
  final String content;
  final bool isLoading;
  final String? error;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onRetry;
  final int? autoScrollTick;
  final List<Note> highlights;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final void Function(Note)? onHighlightTap;
  final ValueChanged<Offset?>? onSelectionGlobalPosition;
  final int? jumpToCharOffset;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onReachEnd;
  final VoidCallback? onReachStart;
  final bool hasNextChapter;
  final bool hasPreviousChapter;
  final bool showChapterTransition;
  final VoidCallback? onJumpHandled;
  final List<ScrollChapterSegment> scrollSegments;
  final Future<void> Function()? onScrollAppendNext;
  final Future<int> Function()? onScrollPrependPrev;
  final void Function(double scrollOffset, double paragraphExtent)?
      onScrollSegmentPosition;
  final VoidCallback? onPaginationBoundaryReset;
  final Widget Function(BuildContext context, ScrollController scrollController)
      scrollBuilder;
  final Widget Function(
    BuildContext context,
    ScrollController scrollController,
    List<BilingualHighlightPair> bilingualPairs,
  )
      bilingualBuilder;
  final Widget Function(BuildContext context, PageController pageController)
      paginatedBuilder;

  const ReaderContent({
    super.key,
    required this.dataSource,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.totalPages,
    required this.renderConfig,
    required this.readingMode,
    this.paginationSkin = PaginationSkin.slide,
    required this.content,
    required this.isLoading,
    required this.scrollBuilder,
    required this.bilingualBuilder,
    required this.paginatedBuilder,
    this.error,
    this.onPageChanged,
    this.onRetry,
    this.autoScrollTick,
    this.highlights = const [],
    this.onSelectionChanged,
    this.onHighlightTap,
    this.onSelectionGlobalPosition,
    this.jumpToCharOffset,
    this.onPositionChanged,
    this.onJumpHandled,
    this.onReachEnd,
    this.onReachStart,
    this.hasNextChapter = false,
    this.hasPreviousChapter = false,
    this.showChapterTransition = true,
    this.scrollSegments = const [],
    this.onScrollAppendNext,
    this.onScrollPrependPrev,
    this.onScrollSegmentPosition,
    this.onPaginationBoundaryReset,
  });

  @override
  Widget build(BuildContext context) {
    final dataSource = this.dataSource;
    final renderConfig = this.renderConfig;
    // 永不重建 PageController — 跨章时手动 jumpToPage(0)
    final pageController = useMemoized(
      () => PageController(initialPage: pageIndex),
      [],
    );
    final scrollController = useScrollController();
    final bilingualPairs = useState<List<BilingualHighlightPair>>([]);
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final nextStaging = dataSource.nextChapterStaging;
    final nextStagingReady = hasNextChapter &&
        nextStaging != null &&
        nextStaging.chapterIndex == chapterId + 1;
    final maxPhysicalPageIndex = () {
      if (totalPages <= 0) return 0;
      return paginationMaxPhysicalPageIndex(
        logicalPageCount: totalPages,
        hasPreviousChapter: hasPreviousChapter,
        hasNextStagingPage: nextStagingReady,
      );
    }();
    int physicalPage(int logicalPage) => paginationPhysicalPageIndex(
          logicalPageIndex: logicalPage,
          hasPreviousChapter: hasPreviousChapter,
        );

    final usePaginationSlide = readingMode == ReadingMode.pagination &&
        paginationSkin == PaginationSkin.slide;

    // 跨章时跳转目标页；adjacent promote 同步 pageIndex（slide 皮肤）
    useEffect(() {
      if (!usePaginationSlide) return null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!pageController.hasClients) return;
        final target = physicalPage(
          pageIndex.clamp(0, totalPages > 0 ? totalPages - 1 : 0),
        ).clamp(0, maxPhysicalPageIndex);
        final current = pageController.page?.round();
        if (current != null && current != target) {
          pageController.jumpToPage(target);
        }
      });
      return null;
    }, [
      chapterId,
      pageIndex,
      showChapterTransition,
      readingMode,
      totalPages,
      hasPreviousChapter,
      nextStagingReady,
    ]);
    // 章内翻页动画同步（仅手动翻页，跨章 promote 已在上方 jumpToPage）
    useEffect(() {
      if (!usePaginationSlide || !showChapterTransition) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageController.hasClients) {
          final target = physicalPage(pageIndex);
          final currentPage = pageController.page?.round();
          if (currentPage != null && currentPage != target) {
            pageController.animateToPage(
              target,
              duration: disableAnim ? Duration.zero : AnimTokens.medium,
              curve: Curves.easeInOut,
            );
          }
        }
      });
      return null;
    }, [
      pageIndex,
      readingMode,
      disableAnim,
      showChapterTransition,
      hasPreviousChapter,
    ]);

    useEffect(() {
      if (readingMode != ReadingMode.bilingual) {
        bilingualPairs.value = [];
        return null;
      }
      () async {
        final pairs = await getBilingualHighlightPairs(
          bookId: bookId,
          chapterIndex: chapterId,
        );
        bilingualPairs.value = pairs;
      }();
      return null;
    }, [bookId, chapterId, readingMode]);

    // Guard against repeated reach-end/start triggers (auto chapter change)
    final reachEndTriggered = useRef(false);
    final reachStartTriggered = useRef(false);
    final hasScrolledBelowTop = useRef(false);
    useEffect(() {
      reachEndTriggered.value = false;
      reachStartTriggered.value = false;
      hasScrolledBelowTop.value = false;
      onPaginationBoundaryReset?.call();
      return null;
    }, [chapterId, scrollSegments.length]);

    useEffect(() {
      if (autoScrollTick == null) return null;

      if (readingMode == ReadingMode.scroll && scrollController.hasClients) {
        final scrollAmount = renderConfig.textRowHeight * 3;
        final newPosition = scrollController.offset + scrollAmount;
        if (newPosition < scrollController.position.maxScrollExtent) {
          scrollController.animateTo(
            newPosition,
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
          );
        } else if (onReachEnd != null &&
            !isLoading &&
            !reachEndTriggered.value) {
          reachEndTriggered.value = true;
          onReachEnd?.call();
        }
      } else if (usePaginationSlide &&
          pageController.hasClients) {
        final nextPage = pageIndex + 1;
        if (nextPage < totalPages) {
          pageController.animateToPage(
            physicalPage(nextPage),
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
          );
          onPageChanged?.call(nextPage);
        }
      }
      return null;
    }, [autoScrollTick]);

    final useScrollSegments = scrollSegments.isNotEmpty;

    useEffect(() {
      if (usePaginationSlide) {
        return null;
      }
      void handleScroll() {
        if (!scrollController.hasClients) {
          return;
        }
        final maxExtent = scrollController.position.maxScrollExtent;
        final threshold = renderConfig.textRowHeight * 1.5;
        final preloadLead = viewportHeight * 1.5;
        if (scrollController.offset > threshold) {
          hasScrolledBelowTop.value = true;
        }

        if (useScrollSegments && !isLoading) {
          final paraHeight =
              renderConfig.textRowHeight + renderConfig.paragraphSpacing;
          onScrollSegmentPosition?.call(
            scrollController.offset,
            paraHeight,
          );

          final nearBottom =
              maxExtent - scrollController.offset <= preloadLead;
          if (hasNextChapter && nearBottom) {
            if (!reachEndTriggered.value) {
              reachEndTriggered.value = true;
              onScrollAppendNext?.call().whenComplete(() {
                reachEndTriggered.value = false;
              });
            }
          }
          if (hasPreviousChapter &&
              hasScrolledBelowTop.value &&
              scrollController.offset <= threshold) {
            if (!reachStartTriggered.value) {
              reachStartTriggered.value = true;
              final beforeMax = scrollController.position.maxScrollExtent;
              final beforeOffset = scrollController.offset;
              onScrollPrependPrev?.call().then((added) {
                if (added <= 0 || !scrollController.hasClients) {
                  reachStartTriggered.value = false;
                  return;
                }
                _compensateScrollAfterPrepend(
                  scrollController,
                  beforeMaxExtent: beforeMax,
                  beforeOffset: beforeOffset,
                  onDone: () => reachStartTriggered.value = false,
                );
              }).catchError((_) {
                reachStartTriggered.value = false;
              });
            }
          }
          return;
        }

        final ratio = maxExtent <= 0
            ? 0.0
            : (scrollController.offset / maxExtent);
        final offset = (ratio * content.length).round().clamp(
          0,
          content.length,
        );
        onPositionChanged?.call(offset);

        if (onReachEnd != null && !isLoading) {
          if (scrollController.offset >= maxExtent - threshold) {
            if (!reachEndTriggered.value) {
              reachEndTriggered.value = true;
              onReachEnd?.call();
            }
          }
        }

        if (onReachStart != null &&
            !isLoading &&
            hasScrolledBelowTop.value &&
            scrollController.offset <= threshold) {
          if (!reachStartTriggered.value) {
            reachStartTriggered.value = true;
            onReachStart?.call();
          }
        }
      }

      scrollController.addListener(handleScroll);
      return () => scrollController.removeListener(handleScroll);
    }, [
      scrollController,
      readingMode,
      content,
      isLoading,
      onReachEnd,
      onReachStart,
      useScrollSegments,
      hasNextChapter,
      hasPreviousChapter,
      onScrollAppendNext,
      onScrollPrependPrev,
      onScrollSegmentPosition,
      viewportHeight,
    ]);

    useEffect(() {
      if (jumpToCharOffset == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (usePaginationSlide) {
          // 页码由 orchestrator 解析；此处只同步 PageController，避免 partial
          // descriptors 下二次推算导致 loadPage 落到上一页。
          final targetIndex = pageIndex.clamp(
            0,
            totalPages > 0 ? totalPages - 1 : 0,
          );
          if (pageController.hasClients) {
            pageController.jumpToPage(physicalPage(targetIndex));
          }
        } else if (scrollController.hasClients) {
          final paraHeight =
              renderConfig.textRowHeight + renderConfig.paragraphSpacing;
          final target = useScrollSegments && scrollSegments.isNotEmpty
              ? ScrollPositionMapper.scrollOffsetForChar(
                  scrollSegments,
                  chapterId,
                  jumpToCharOffset!,
                  paraHeight,
                )
              : (content.isEmpty
                  ? 0.0
                  : (scrollController.position.maxScrollExtent *
                      (jumpToCharOffset! / content.length)));
          final maxExtent = scrollController.position.maxScrollExtent;
          scrollController.animateTo(
            target.clamp(0.0, maxExtent),
            duration: AnimTokens.normal,
            curve: Curves.easeInOut,
          );
          onPositionChanged?.call(jumpToCharOffset!.clamp(0, content.length));
        }
        onJumpHandled?.call();
      });
      return null;
    }, [
      jumpToCharOffset,
      pageIndex,
      totalPages,
      readingMode,
      bookId,
      chapterId,
      content,
      scrollSegments,
    ]);
    // 跨章节 slide 方向追踪（在 pageTurn/pagination 条件返回前声明）
    final prevChapterId = useRef<int?>(null);
    final isForward =
        prevChapterId.value != null && chapterId > prevChapterId.value!;
    useEffect(() {
      prevChapterId.value = chapterId;
      return null;
    }, [chapterId]);

    // pageTurn 与 pagination 共用 PaginatedModeRenderer（见 PageTurnShell）
    final contentWidget = _buildContent(
      context,
      pageController,
      scrollController,
      bilingualPairs.value,
    );

    if (usePaginationSlide) {
      if (showChapterTransition) {
        final slideX = isForward ? 1.0 : -1.0;
        return AnimatedSwitcher(
          duration: AnimTokens.medium,
          switchInCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: Offset(slideX, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: Container(
            key: ValueKey('chapter_$chapterId'),
            color: renderConfig.backgroundColor,
            child: contentWidget,
          ),
        );
      }
      // adjacentCrossChapter promote：直接渲染，无 AnimatedSwitcher 过渡
      return Container(
        key: const ValueKey('promote_content'),
        color: renderConfig.backgroundColor,
        child: contentWidget,
      );
    }
    return Container(color: renderConfig.backgroundColor, child: contentWidget);
  }

  Widget _buildContent(
    BuildContext context,
    PageController pageController,
    ScrollController scrollController,
    List<BilingualHighlightPair> bilingualPairs,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final error = this.error;
    if (isLoading) {
      return const SizedBox(key: ValueKey('reader_loading'));
    }
    if (error != null) {
      return Center(
        key: const ValueKey('reader_error'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 64,
              color: Colors.red[300],
            ),
            Text(
              l10n.chapterLoadFailed(error),
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (content.isEmpty) {
      return Center(child: Text(l10n.contentEmpty));
    }
    switch (readingMode) {
      case ReadingMode.scroll:
        return RepaintBoundary(child: scrollBuilder(context, scrollController));
      case ReadingMode.bilingual:
        return RepaintBoundary(
          child: bilingualBuilder(context, scrollController, bilingualPairs),
        );
      case ReadingMode.pagination:
        return RepaintBoundary(
          child: paginatedBuilder(context, pageController),
        );
    }
  }

  static Color getTextColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return Colors.grey[300]!;
      case ThemeMode.light:
      default:
        return Colors.black87;
    }
  }

  static Color getBackgroundColor(ThemeMode themeMode, int bgIndex) {
    switch (themeMode) {
      case ThemeMode.dark:
        return ReaderBgColors.darkBackground;
      case ThemeMode.light:
      default:
        final presets = ReaderBgColors.presets;
        return presets[bgIndex.clamp(0, presets.length - 1)];
    }
  }

  /// prepend 后按 maxScrollExtent 增量补偿，避免视口跳动。
  static void _compensateScrollAfterPrepend(
    ScrollController controller, {
    required double beforeMaxExtent,
    required double beforeOffset,
    required VoidCallback onDone,
    int pass = 0,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) {
        onDone();
        return;
      }
      final afterMax = controller.position.maxScrollExtent;
      final delta = afterMax - beforeMaxExtent;
      if (delta <= 0 && pass < 2) {
        _compensateScrollAfterPrepend(
          controller,
          beforeMaxExtent: beforeMaxExtent,
          beforeOffset: beforeOffset,
          onDone: onDone,
          pass: pass + 1,
        );
        return;
      }
      if (delta > 0) {
        controller.jumpTo(
          (beforeOffset + delta).clamp(0.0, afterMax),
        );
      }
      onDone();
    });
  }
}
