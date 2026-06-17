import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_renderer.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import '../../core/data/reader_render_data_source.dart';

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
  final WritingDirection writingDirection;
  final int? jumpToCharOffset;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onReachEnd;
  final VoidCallback? onReachStart;
  final bool hasNextChapter;
  final bool hasPreviousChapter;
  final VoidCallback? onJumpHandled;

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
    this.writingDirection = WritingDirection.horizontal,
    this.jumpToCharOffset,
    this.onPositionChanged,
    this.onJumpHandled,
    this.onReachEnd,
    this.onReachStart,
    this.hasNextChapter = false,
    this.hasPreviousChapter = false,
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

    // 跨章时直接跳转第 0 页，不带动画
    useEffect(() {
      if (pageController.hasClients) {
        pageController.jumpToPage(0);
      }
      return null;
    }, [chapterId]);

    // 章内翻页动画同步
    useEffect(() {
      if (readingMode != ReadingMode.pagination) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageController.hasClients) {
          final currentPage = pageController.page?.round();
          if (currentPage != null && currentPage != pageIndex) {
            pageController.animateToPage(
              pageIndex,
              duration: disableAnim ? Duration.zero : AnimTokens.medium,
              curve: Curves.easeInOut,
            );
          }
        }
      });
      return null;
    }, [pageIndex, readingMode, disableAnim]);

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
      return null;
    }, [chapterId]);

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
      } else if (readingMode == ReadingMode.pagination &&
          pageController.hasClients) {
        final nextPage = pageIndex + 1;
        if (nextPage < totalPages) {
          pageController.animateToPage(
            nextPage,
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
          );
          onPageChanged?.call(nextPage);
        }
      }
      return null;
    }, [autoScrollTick]);

    useEffect(() {
      if (readingMode == ReadingMode.pagination) {
        return null;
      }
      void handleScroll() {
        if (!scrollController.hasClients) {
          return;
        }
        final maxExtent = scrollController.position.maxScrollExtent;
        final ratio = maxExtent <= 0
            ? 0.0
            : (scrollController.offset / maxExtent);
        final offset = (ratio * content.length).round().clamp(
          0,
          content.length,
        );
        onPositionChanged?.call(offset);

        final threshold = renderConfig.textRowHeight * 1.5;
        if (scrollController.offset > threshold) {
          hasScrolledBelowTop.value = true;
        }

        // Auto-next-chapter: detect near bottom of scroll
        if (onReachEnd != null && !isLoading) {
          if (scrollController.offset >= maxExtent - threshold) {
            if (!reachEndTriggered.value) {
              reachEndTriggered.value = true;
              onReachEnd?.call();
            }
          }
        }

        // Auto-previous-chapter: detect near top after user scrolled down first
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

      return () => scrollController.removeListener(handleScroll);
    }, [scrollController, readingMode, content, isLoading, onReachEnd, onReachStart]);

    useEffect(() {
      if (jumpToCharOffset == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (readingMode == ReadingMode.pagination) {
          final descriptors = dataSource.descriptors;
          if (descriptors != null && descriptors.isNotEmpty) {
            final targetIndex = _indexForCharOffset(
              descriptors,
              jumpToCharOffset!,
              (d) => d.startOffset,
              (d) => d.endOffset,
            );
            if (pageController.hasClients) {
              pageController.jumpToPage(targetIndex);
            }
            onPageChanged?.call(targetIndex);
            onPositionChanged?.call(descriptors[targetIndex].startOffset);
          }
        } else if (scrollController.hasClients) {
          final maxExtent = scrollController.position.maxScrollExtent;
          final ratio = content.isEmpty
              ? 0.0
              : (jumpToCharOffset! / content.length);
          final target = (maxExtent * ratio).clamp(0.0, maxExtent);
          scrollController.animateTo(
            target,
            duration: AnimTokens.normal,
            curve: Curves.easeInOut,
          );
          onPositionChanged?.call(jumpToCharOffset!.clamp(0, content.length));
        }
        onJumpHandled?.call();
      });
      return null;
    }, [jumpToCharOffset, readingMode, bookId, chapterId, content]);
    // 跨章节 slide 方向追踪（在 pageTurn/pagination 条件返回前声明）
    final prevChapterId = useRef<int?>(null);
    final isForward =
        prevChapterId.value != null && chapterId > prevChapterId.value!;
    useEffect(() {
      prevChapterId.value = chapterId;
      return null;
    }, [chapterId]);

    // pageTurn mode: bypass AnimatedSwitcher, use interactive PageCurlWidget
    if (readingMode == ReadingMode.pageTurn &&
        !isLoading &&
        error == null &&
        content.isNotEmpty) {
      final descriptors = dataSource.descriptors;
      // ignore: unused_local_variable
      final preloadGen = useListenable(dataSource.preloadGeneration);
      final staging = dataSource.nextChapterStaging;
      final stagingReady = hasNextChapter &&
          staging != null &&
          staging.chapterIndex == chapterId + 1;
      final extendedTotal = totalPages + (stagingReady ? 1 : 0);
      Widget pageBuilder(int idx) {
        // 虚拟跨章页：使用预加载 staging 内容
        if (idx >= totalPages) {
          final staging = dataSource.nextChapterStaging;
          // 校验 staging 属于下一章（防御性，正常流程由 _stagingGen 防护）
          if (staging != null && staging.chapterIndex == chapterId + 1) {
            dataSource.warmPageCache(totalPages, staging.firstPageContent);
            final startOffset = staging.descriptors.isNotEmpty
                ? staging.descriptors[0].startOffset
                : 0;
            return buildSinglePageContent(
              context: context,
              pageIndex: totalPages,
              startOffset: startOffset,
              dataSource: dataSource,
              config: renderConfig,
              highlights: highlights,
              writingDirection: writingDirection,
              onHighlightTap: onHighlightTap,
              onSelectionChanged: onSelectionChanged,
              onSelectionGlobalPosition: onSelectionGlobalPosition,
            );
          }
        }
        final startOffset = (descriptors != null && idx < descriptors.length)
            ? descriptors[idx].startOffset
            : 0;
        return buildSinglePageContent(
          context: context,
          pageIndex: idx,
          startOffset: startOffset,
          dataSource: dataSource,
          config: renderConfig,
          highlights: highlights,
          writingDirection: writingDirection,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
        );
      }

      return PageCurlWidget(
        pageIndex: pageIndex,
        totalPages: extendedTotal,
        hasPreviousChapter: hasPreviousChapter,
        onReachStart: onReachStart,
        pageBuilder: pageBuilder,
        onPageChanged: (index) {
          // 跨章节翻页 → 异步加载下一章（仍更新 pageIndex 防止 PageCurl 回弹）
          if (index >= totalPages) {
            onReachEnd?.call();
          }
          onPageChanged?.call(index);
          if (descriptors != null && index < descriptors.length) {
            onPositionChanged?.call(descriptors[index].startOffset);
          }
        },
      );
    }

    final contentWidget = _buildContent(
      context,
      pageController,
      scrollController,
      bilingualPairs.value,
    );

    if (readingMode == ReadingMode.pagination) {
      final slideX = isForward ? 1.0 : -1.0;
      return AnimatedSwitcher(
        duration: AnimTokens.medium,
        switchInCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          // 进入 child: animation 0→1, Offset(slideX→0) ✓ 外→中
          // 离开 child: animation 1→0, Offset(0→slideX) 中→外方向一致
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
      case ReadingMode.pageTurn:
        return const SizedBox.shrink();
    }
  }

  /// 在 [items] 中查找 [charOffset] 所在的区间 [startOffset, endOffset)。
  /// 返回第一个匹配的索引；无匹配时返回最后一项的索引。
  static int _indexForCharOffset<T>(
    List<T> items,
    int charOffset,
    int Function(T) startOffset,
    int Function(T) endOffset,
  ) {
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (charOffset >= startOffset(item) && charOffset < endOffset(item)) {
        return i;
      }
    }
    return items.length - 1;
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
}
