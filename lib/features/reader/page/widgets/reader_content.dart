import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../data/repositories/rust_reader_repository.dart';
import 'bilingual_renderer.dart';
import 'page_curl_widget.dart';
import 'paginated_renderer.dart';
import 'reader_render_config.dart';
import 'reader_skeleton.dart';
import 'scroll_mode_renderer.dart';

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
  final String searchQuery;
  final bool searchMatchHighlight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final int bgIndex;
  final WritingDirection writingDirection;
  final bool showVocabularyMark;
  final Set<String> vocabularyWords;
  final bool baselineAlign;
  final bool showSentenceSplit;
  final int? jumpToCharOffset;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onReachEnd;

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
    this.searchQuery = '',
    this.searchMatchHighlight = false,
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
    this.baselineAlign = true,
  });

  @override
  Widget build(BuildContext context) {
    final repo = this.repo;
    final pageController = useMemoized(
      () => PageController(initialPage: pageIndex),
      [chapterId],
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
        searchQuery: searchQuery,
        searchMatchHighlight: searchMatchHighlight,
        showVocabularyMark: showVocabularyMark,
        vocabularyWords: vocabularyWords,
        baselineAlign: baselineAlign,
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
        searchQuery,
        searchMatchHighlight,
        showVocabularyMark,
        vocabularyWords,
        baselineAlign,
      ],
    );

    useEffect(() {
      if (readingMode != ReadingMode.pagination || disableAnim) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageController.hasClients) {
          pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
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
            duration: const Duration(milliseconds: 300),
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
            duration: const Duration(milliseconds: 300),
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
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
          onPositionChanged?.call(jumpToCharOffset!.clamp(0, content.length));
        }
        onJumpHandled?.call();
      });
      return null;
    }, [jumpToCharOffset, readingMode, bookId, chapterId, content]);
    // Must call useRef unconditionally (hook ordering rule).
    final prevPageIndex = useRef(pageIndex);

    // pageTurn mode: bypass AnimatedSwitcher, use interactive PageCurlWidget
    if (readingMode == ReadingMode.pageTurn &&
        !isLoading &&
        error == null &&
        content.isNotEmpty) {
      final descriptors = repo.descriptors;
      Widget pageBuilder(int idx) {
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
        totalPages: totalPages,
        pageBuilder: pageBuilder,
        onPageChanged: (index) {
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

    final isForward = pageIndex >= prevPageIndex.value;
    prevPageIndex.value = pageIndex;

    final contentKey = isLoading
        ? const ValueKey('loading')
        : error != null
        ? const ValueKey('error')
        : readingMode != ReadingMode.pagination
        ? ValueKey('${readingMode}_${chapterId}_$pageIndex')
        : ValueKey('${readingMode}_$chapterId');

    return Container(
      color: backgroundColor,
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: disableAnim
              ? 0
              : readingMode == ReadingMode.pagination
              ? 200
              : 250,
        ),
        switchInCurve: readingMode == ReadingMode.scroll
            ? Curves.easeOut
            : Curves.easeOutCubic,
        switchOutCurve: readingMode == ReadingMode.scroll
            ? Curves.easeIn
            : Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          switch (readingMode) {
            case ReadingMode.pagination:
              final offset = isForward
                  ? const Offset(0.15, 0)
                  : const Offset(-0.15, 0);
              return SlideTransition(
                position: Tween<Offset>(begin: offset, end: Offset.zero)
                    .animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: child,
              );
            default:
              return FadeTransition(opacity: animation, child: child);
          }
        },
        child: KeyedSubtree(key: contentKey, child: contentWidget),
      ),
    );
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
      return ReaderSkeleton(
        backgroundColor: backgroundColor,
        pageMargin: pageMargin,
        fontSize: renderConfig.fontSize,
        lineHeight: renderConfig.lineHeight,
        brightness: brightness,
      );
    }

    if (error != null) {
      return Center(
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
