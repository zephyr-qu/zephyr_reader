import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/page/renderer/bilingual_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/page/renderer/scroll_mode_renderer.dart';
import 'package:zephyr_reader/features/reader/page/ui/page_curl_widget.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import '../../data/repositories/rust_reader_repository.dart';

/// 阅读内容容器组件。
///
/// 根据当前阅读模式（分页/滚动/双语）选择对应渲染器展示书籍内容。
/// 集成高亮显示、翻页动画、双向滚动等阅读交互功能。
class ReaderContent extends HookWidget {
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final int totalPages;
  final ReaderRepository repo;
  final double fontSize;
  final double lineHeight;
  final ThemeMode themeMode;
  final ReadingMode readingMode;
  final String content;

  final bool isLoading;
  final String? error;
  final BilingualAlignment? bilingualAlignment;
  final bool isBilingualLoading;
  final String? bilingualError;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onRequestTranslation;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryTranslation;
  final int? autoScrollTick;
  final List<Note> highlights;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final void Function(Note)? onHighlightTap;
  final ValueChanged<Offset?>? onSelectionGlobalPosition;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final int bgIndex;
  final WritingDirection writingDirection;
  final bool showVocabularyMark;
  final Set<String> vocabularyWords;
  final bool baselineAlign;
  final TextAlign textAlign;
  final bool showSentenceSplit;
  final int? jumpToCharOffset;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onReachEnd;

  /// 是否有下一章（用于 pageTurn 模式扩展页面范围）
  final bool hasNextChapter;

  final VoidCallback? onJumpHandled;

  const ReaderContent({
    super.key,
    required this.repo,
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.totalPages,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    required this.readingMode,
    required this.content,
    required this.isLoading,
    this.error,
    this.bilingualAlignment,
    this.isBilingualLoading = false,
    this.bilingualError,
    this.onPageChanged,
    this.onRequestTranslation,
    this.onRetryTranslation,
    this.onRetry,
    this.autoScrollTick,
    this.highlights = const [],
    this.onSelectionChanged,
    this.onHighlightTap,
    this.onSelectionGlobalPosition,
    this.fontFamily = 'Noto Sans SC',
    this.letterSpacing = 0,
    this.paragraphSpacing = 12,
    this.pageMargin = 16,
    this.writingDirection = WritingDirection.horizontal,
    this.showVocabularyMark = false,
    this.vocabularyWords = const {},
    this.bgIndex = 0,
    this.showSentenceSplit = false,
    this.jumpToCharOffset,
    this.onPositionChanged,
    this.onJumpHandled,
    this.onReachEnd,
    this.hasNextChapter = false,
    this.baselineAlign = true,
    this.textAlign = TextAlign.justify,
  });

  @override
  Widget build(BuildContext context) {
    final repo = this.repo;
    // 永不重建 PageController — 跨章时手动 jumpToPage(0)
    final pageController = useMemoized(
      () => PageController(initialPage: pageIndex),
      [],
    );
    final scrollController = useScrollController();
    final textColor = _getTextColor(themeMode);
    final backgroundColor = _getBackgroundColor(themeMode);
    final bilingualPairs = useState<List<BilingualHighlightPair>>([]);
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    final renderConfig = useMemoized(
      () => ReaderRenderConfig(
        textColor: textColor,
        backgroundColor: backgroundColor,
        fontSize: fontSize,
        lineHeight: lineHeight,
        fontFamily: fontFamily,
        letterSpacing: letterSpacing,
        paragraphSpacing: paragraphSpacing,
        pageMargin: pageMargin,
        showVocabularyMark: showVocabularyMark,
        vocabularyWords: vocabularyWords,
        baselineAlign: baselineAlign,
        textAlign: textAlign,
      ),
      [
        textColor,
        backgroundColor,
        fontSize,
        lineHeight,
        fontFamily,
        letterSpacing,
        paragraphSpacing,
        pageMargin,
        baselineAlign,
        textAlign,
        vocabularyWords,
      ],
    );

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
              duration: disableAnim
                  ? Duration.zero
                  : AnimTokens.medium,
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

    // Guard against repeated reach-end triggers (auto-next-chapter)
    final reachEndTriggered = useRef(false);
    useEffect(() {
      reachEndTriggered.value = false;
      return null;
    }, [chapterId]);

    useEffect(() {
      if (autoScrollTick == null) return null;

      if (readingMode == ReadingMode.scroll && scrollController.hasClients) {
        final scrollAmount = fontSize * lineHeight * 3;
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

        // Auto-next-chapter: detect near bottom of scroll
        if (onReachEnd != null && !isLoading) {
          final threshold = fontSize * lineHeight * 1.5;
          if (scrollController.offset >= maxExtent - threshold) {
            if (!reachEndTriggered.value) {
              reachEndTriggered.value = true;
              onReachEnd?.call();
            }
          }
        }
      }

      scrollController.addListener(handleScroll);
      return () => scrollController.removeListener(handleScroll);
    }, [scrollController, readingMode, content, isLoading, onReachEnd]);

    useEffect(() {
      if (jumpToCharOffset == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (readingMode == ReadingMode.pagination) {
          // 新版：使用描述符
          final descriptors = repo.descriptors;
          if (descriptors != null && descriptors.isNotEmpty) {
            final targetIndex = (() {
              for (int i = 0; i < descriptors.length; i++) {
                if (jumpToCharOffset! >= descriptors[i].startOffset &&
                    jumpToCharOffset! < descriptors[i].endOffset) {
                  return i;
                }
              }
              return descriptors.length - 1;
            })();
            if (pageController.hasClients) {
              pageController.jumpToPage(targetIndex);
            }
            onPageChanged?.call(targetIndex);
            onPositionChanged?.call(descriptors[targetIndex].startOffset);
          } else {
            // 旧版：使用预计算的全量 PageInfo
            final pages = repo.currentPages;
            if (pages != null && pages.isNotEmpty) {
              final targetIndex = (() {
                for (int i = 0; i < pages.length; i++) {
                  if (jumpToCharOffset! >= pages[i].startOffset &&
                      jumpToCharOffset! < pages[i].endOffset) {
                    return i;
                  }
                }
                return pages.length - 1;
              })();
              if (pageController.hasClients) {
                pageController.jumpToPage(targetIndex);
              }
              onPageChanged?.call(targetIndex);
              onPositionChanged?.call(pages[targetIndex].startOffset);
            }
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
    // Must call useRef unconditionally (hook ordering rule).
    // ignore: unused_local_variable
    final prevPageIndex = useRef(pageIndex);
    // 跨章节 slide 方向追踪（在 pageTurn/pagination 条件返回前声明）
    final prevChapterId = useRef<int?>(null);
    final isForward = prevChapterId.value != null &&
        chapterId > prevChapterId.value!;
    useEffect(() {
      prevChapterId.value = chapterId;
      return null;
    }, [chapterId]);

    // pageTurn mode: bypass AnimatedSwitcher, use interactive PageCurlWidget
    if (readingMode == ReadingMode.pageTurn &&
        !isLoading &&
        error == null &&
        content.isNotEmpty) {
      final descriptors = repo.descriptors;
      // 始终允许跨章节翻页（preload 异步完成后通过 notifier 触发重建更新内容）
      // ignore: unused_local_variable
      final preloadGen = useListenable(repo.preloadGeneration);
      final hasNext = hasNextChapter;
      final extendedTotal = totalPages + (hasNext ? 1 : 0);
      Widget pageBuilder(int idx) {
        // 跨章节翻页：缓存预加载内容到 pageCache，通过 buildSinglePageContent 统一渲染
        if (idx >= (descriptors?.length ?? totalPages) &&
            hasNext &&
            idx < extendedTotal) {
          final preloaded = repo.getPreloadedNextChapterContent(chapterId + 1);
          if (preloaded != null) {
            // 存入 pageCache，使 getPageContent 可查询 → buildSinglePageContent 统一渲染
            repo.warmPageCache(idx, preloaded);
          }
        }
        final startOffset = (descriptors != null && idx < descriptors.length)
            ? descriptors[idx].startOffset
            : 0;
        return buildSinglePageContent(
          context: context,
          pageIndex: idx,
          startOffset: startOffset,
          repo: repo,
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
        pageBuilder: pageBuilder,
        onPageChanged: (index) {
          // 跨章节翻页 → 异步加载下一章
          if (index >= totalPages && onReachEnd != null) {
            onReachEnd!();
          }
          // 必须更新 pageIndex signal，否则 PageCurlWidget 在动画完成后
          // 会回退到旧页内容（widget.pageIndex 未改变）
          onPageChanged?.call(index);
          if (descriptors != null && index < descriptors.length) {
            onPositionChanged?.call(descriptors[index].startOffset);
          }
        },
      );
    }

    final contentWidget = _buildContent(
      context,
      content,
      isLoading,
      error,
      textColor,
      backgroundColor,
      pageController,
      scrollController,
      repo,
      bilingualPairs.value,
      renderConfig,
      themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      pageMargin,
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
          color: backgroundColor,
          child: contentWidget,
        ),
      );
    }
    return Container(color: backgroundColor, child: contentWidget);
  }

  Widget _buildContent(
    BuildContext context,
    String content,
    bool isLoading,
    String? error,
    Color textColor,
    Color backgroundColor,
    PageController pageController,
    ScrollController scrollController,
    ReaderRepository repo,
    List<BilingualHighlightPair> bilingualPairs,
    ReaderRenderConfig renderConfig,
    Brightness brightness,
    double pageMargin,
  ) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      // 分段读取模式下首屏文字在 ~100ms 内到达，
      // 骨架屏仅闪烁一帧反而影响体验，直接占位。
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

    if (readingMode == ReadingMode.scroll) {
      return RepaintBoundary(
        child: ScrollModeRenderer(
          config: renderConfig,
          scrollController: scrollController,
          repo: repo,
          bookId: bookId,
          chapterId: chapterId,
          content: content,
          highlights: highlights,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
          writingDirection: writingDirection,
          showSentenceSplit: showSentenceSplit,
        ),
      );
    } else if (readingMode == ReadingMode.bilingual) {
      return RepaintBoundary(
        child: BilingualModeRenderer(
          config: renderConfig,
          scrollController: scrollController,
          bilingualPairs: bilingualPairs,
          isBilingualLoading: isBilingualLoading,
          bilingualError: bilingualError,
          bilingualAlignment: bilingualAlignment,
          highlights: highlights,
          onRequestTranslation: onRequestTranslation,
          onRetryTranslation: onRetryTranslation,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
          writingDirection: writingDirection,
        ),
      );
    } else {
      return RepaintBoundary(
        child: PaginatedModeRenderer(
          config: renderConfig,
          pageController: pageController,
          repo: repo,
          bookId: bookId,
          chapterId: chapterId,
          pageIndex: pageIndex,
          content: content,
          highlights: highlights,
          readingMode: readingMode,
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
          onPageChanged: onPageChanged,
          onPositionChanged: onPositionChanged,
          writingDirection: writingDirection,
        ),
      );
    }
  }

  Color _getTextColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return Colors.grey[300]!;
      case ThemeMode.light:
      default:
        return Colors.black87;
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
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
