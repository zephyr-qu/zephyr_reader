import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_page_bindings.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../data/repositories/rust_reader_repository.dart';
import 'bilingual_renderer.dart';
import 'paginated_renderer.dart';
import 'page_turn_painter.dart';
import 'reader_render_config.dart';
import 'scroll_mode_renderer.dart';

class ReaderContent extends HookWidget {
  final String bookId;
  final int chapterId;
  final int pageIndex;
  final int totalPages;
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
  final bool showSentenceSplit;
  final int? jumpToCharOffset;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onJumpHandled;

  const ReaderContent({
    super.key,
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
  });

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => GetIt.I.get<ReaderRepository>());
    final pageController = usePageController();
    final scrollController = useScrollController();
    final textColor = _getTextColor(themeMode);
    final backgroundColor = _getBackgroundColor(themeMode);
    final bilingualPairs = useState<List<BilingualHighlightPair>>([]);
    final disableAnim = MediaQuery.of(context).disableAnimations;

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
      ],
    );

    useEffect(() {
      if (readingMode == ReadingMode.pagination &&
          pageController.hasClients &&
          !disableAnim) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        });
      }
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
      }

      scrollController.addListener(handleScroll);
      return () => scrollController.removeListener(handleScroll);
    }, [scrollController, readingMode, content]);

    useEffect(() {
      if (jumpToCharOffset == null) {
        return null;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (readingMode == ReadingMode.pagination) {
          final pages = repo.currentPages;
          if (pages != null && pages.isNotEmpty) {
            final targetIndex = (() {
              for (int i = 0; i < pages.length; i++) {
                if (jumpToCharOffset! >= pages[i].startOffset &&
                    jumpToCharOffset! < pages[i].endOffset) {
                  return i;
                }
              }
              return pages.isEmpty ? 0 : pages.length - 1;
            })();
            if (pageController.hasClients) {
              pageController.jumpToPage(targetIndex);
            }
            onPageChanged?.call(targetIndex);
            onPositionChanged?.call(pages[targetIndex].startOffset);
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
    );

    final prevPageIndex = useRef(pageIndex);
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
            case ReadingMode.scroll:
              return FadeTransition(opacity: animation, child: child);
            case ReadingMode.bilingual:
              return FadeTransition(opacity: animation, child: child);
            case ReadingMode.pageTurn:
              return PageTurnTransitionBuilder(
                animation: animation,
                isForward: isForward,
                child: child,
              );
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
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
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
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onRetry, child: const Text('重新加载')),
          ],
        ),
      );
    }

    if (content.isEmpty) {
      return const Center(child: Text('内容为空'));
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
          onHighlightTap: onHighlightTap,
          onSelectionChanged: onSelectionChanged,
          onSelectionGlobalPosition: onSelectionGlobalPosition,
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

class ReaderContentView extends HookWidget {
  final ReaderViewModel vm;
  final VoidCallback? onRequestTranslation;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onJumpHandled;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final ValueChanged<Offset?>? onSelectionGlobalPosition;
  final void Function(Note)? onHighlightTap;
  final Set<String> vocabularyWords;

  const ReaderContentView({
    super.key,
    required this.vm,
    this.onRequestTranslation,
    this.onPositionChanged,
    this.onJumpHandled,
    this.onSelectionChanged,
    this.onSelectionGlobalPosition,
    this.onHighlightTap,
    this.vocabularyWords = const {},
  });

  @override
  Widget build(BuildContext context) {
    final b = useReaderContentBindings(vm);
    final fontFamily = useMemoized(
      () => GetIt.I.get<FontRepository>(),
    ).currentFontFamily;

    return ReaderContent(
      bookId: b.currentBookId,
      chapterId: b.chapterIndex,
      pageIndex: b.pageIndex,
      totalPages: b.totalPages,
      fontSize: b.fontSize,
      lineHeight: b.lineHeight,
      themeMode: b.themeMode,
      readingMode: b.currentReadingMode,
      content: b.content,
      isLoading: b.isLoading,
      error: b.error,
      bilingualAlignment: b.bilingualAlign,
      isBilingualLoading: b.isBilingualLoading,
      bilingualError: b.bilingualError,
      onRequestTranslation: onRequestTranslation ?? () {},
      onPageChanged: vm.loadPage,
      onRetry: () => vm.loadChapter(
        b.chapterIndex,
        initialCharOffset: vm.currentCharOffset.value,
        restartSession: false,
      ),
      autoScrollTick: b.autoScrollTick,
      highlights: b.highlights,
      onSelectionChanged: onSelectionChanged,
      onSelectionGlobalPosition: onSelectionGlobalPosition,
      onHighlightTap: (note) {
        if (onHighlightTap != null) {
          onHighlightTap!(note);
        }
      },
      fontFamily: fontFamily,
      searchQuery: b.searchQuery,
      searchMatchHighlight: b.searchMatchHighlight,
      letterSpacing: b.letterSpacing,
      paragraphSpacing: b.paragraphSpacing,
      pageMargin: b.pageMargin,
      writingDirection: b.writingDirection,
      showVocabularyMark: true,
      vocabularyWords: vocabularyWords,
      showSentenceSplit: true,
      bgIndex: 0,
      jumpToCharOffset: b.pendingJumpCharOffset,
      onPositionChanged: onPositionChanged ?? vm.updateCurrentCharOffset,
      onJumpHandled: onJumpHandled ?? vm.consumePendingJumpOffset,
    );
  }
}
