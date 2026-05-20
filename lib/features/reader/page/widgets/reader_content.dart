import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:zephyr_reader/core/reader/font_config.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/api/bilingual_highlight.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../application/reader_view_model.dart';
import '../../data/repositories/rust_reader_repository.dart';
import '../../domain/services/highlight_painter.dart';
import '../../../../core/utils/adaptive_scroll_physics.dart';

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

  Set<String> get _effectiveVocabWords =>
      showVocabularyMark ? vocabularyWords : const {};

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
    final pageController = usePageController();
    final scrollController = useScrollController();
    final repo = useMemoized(() => GetIt.I.get<ReaderRepository>());
    final bilingualPairs = useState<List<BilingualHighlightPair>>([]);

    final textColor = _getTextColor(themeMode);
    final backgroundColor = _getBackgroundColor(themeMode);

    useEffect(() {
      if (readingMode == ReadingMode.pagination && pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        });
      }
      return null;
    }, [pageIndex, readingMode]);

    useEffect(() {
      if (readingMode != ReadingMode.bilingual) {
        bilingualPairs.value = [];
        return null;
      }
      getBilingualHighlightPairs(bookId: bookId, chapterIndex: chapterId).then((
        pairs,
      ) {
        bilingualPairs.value = pairs;
      });
      return null;
    }, [bookId, chapterId, readingMode, highlights.length]);

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
          final pages = repo.getCachedPages(bookId, chapterId);
          if (pages != null && pages.isNotEmpty) {
            final targetIndex = _findPageIndexForOffset(
              pages,
              jumpToCharOffset!,
            );
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
    );

    final prevPageIndex = useRef(pageIndex);
    final isForward = pageIndex >= prevPageIndex.value;
    prevPageIndex.value = pageIndex;

    final usePageKey = readingMode != ReadingMode.pagination;
    final contentKey = isLoading
        ? const ValueKey('loading')
        : error != null
        ? const ValueKey('error')
        : usePageKey
        ? ValueKey('${readingMode}_${content.length}_$pageIndex')
        : ValueKey('${readingMode}_${content.length}');

    return Container(
      color: backgroundColor,
      child: RepaintBoundary(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = isForward
                ? const Offset(0.3, 0)
                : const Offset(-0.3, 0);
            return SlideTransition(
              position: Tween<Offset>(
                begin: offset,
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: KeyedSubtree(key: contentKey, child: contentWidget),
        ),
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
      return _buildScrollMode(
        content,
        textColor,
        scrollController,
        repo,
        context,
      );
    } else if (readingMode == ReadingMode.bilingual) {
      return _buildBilingualMode(
        context,
        textColor,
        backgroundColor,
        bilingualPairs,
        scrollController,
      );
    } else {
      return _buildPaginationMode(
        context,
        content,
        textColor,
        backgroundColor,
        pageController,
        repo,
      );
    }
  }

  /// 从合并的 Rich TextSpan 树中提取逐段落的 TextSpan 列表
  List<TextSpan> _extractParagraphSpans(TextSpan rootSpan) {
    if (rootSpan.children == null || rootSpan.children!.isEmpty) {
      return [rootSpan];
    }
    final paragraphs = <TextSpan>[];
    var currentChildren = <InlineSpan>[];
    for (final child in rootSpan.children!) {
      if (child is! TextSpan) continue;
      if (child.text == '\n\n') {
        if (currentChildren.isNotEmpty) {
          paragraphs.add(TextSpan(children: currentChildren));
          currentChildren = [];
        }
      } else {
        currentChildren.add(child);
      }
    }
    if (currentChildren.isNotEmpty) {
      paragraphs.add(TextSpan(children: currentChildren));
    }
    return paragraphs;
  }

  Widget _buildScrollMode(
    String content,
    Color textColor,
    ScrollController scrollController,
    ReaderRepository repo,
    BuildContext context,
  ) {
    if (writingDirection == WritingDirection.vertical) {
      return _buildVerticalScrollMode(
        content,
        textColor,
        scrollController,
        repo,
        context,
      );
    }
    final richSpan = repo.getCachedRichTextSpan(bookId, chapterId);
    final textStyle = FontConfig.readerStyle(
      fontSize: fontSize,
      lineHeight: lineHeight,
      color: textColor,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );
    final strutStyle = FontConfig.readerStrut(
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
    );

    if (richSpan != null) {
      final richParagraphs = repo.getCachedRichParagraphs(bookId, chapterId);
      if (richParagraphs != null && richParagraphs.any((p) => p.isImage)) {
        return _buildRichScrollWithImages(
          richParagraphs,
          richSpan,
          textStyle,
          strutStyle,
          scrollController,
          context,
        );
      }
      final paragraphs = _extractParagraphSpans(richSpan);
      if (paragraphs.isEmpty) {
        return const Center(child: Text('内容为空'));
      }
      var accOffset = 0;
      final paraOffsets = paragraphs.map((p) {
        final o = accOffset;
        accOffset += _spanTextLength(p) + 2;
        return o;
      }).toList();
      return ListView.builder(
        controller: scrollController,
        physics: adaptiveScrollPhysics(context),
        padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
        itemCount: paragraphs.length,
        itemBuilder: (context, index) {
          final painted = HighlightPainter.paintRich(
            paragraphs[index],
            paraOffsets[index],
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: searchQuery,
            searchMatchHighlight: searchMatchHighlight,
            vocabularyWords: _effectiveVocabWords,
          );
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index < paragraphs.length - 1 ? paragraphSpacing : 0,
              ),
              child: SelectableText.rich(
                painted,
                style: textStyle,
                strutStyle: strutStyle,
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) => _onRichSelectionChanged(
                  sel,
                  paragraphs[index],
                  paraOffsets[index],
                  context,
                ),
                contextMenuBuilder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      );
    }

    final paragraphList = content
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => _splitLongSentence(p))
        .toList();
    if (paragraphList.isEmpty) {
      return const Center(child: Text('内容为空'));
    }
    var acc = 0;
    final offsets = paragraphList.map((p) {
      final o = acc;
      acc += p.length + 2;
      return o;
    }).toList();
    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
      itemCount: paragraphList.length,
      itemBuilder: (context, index) {
        final painted = HighlightPainter.paintPlain(
          paragraphList[index],
          textStyle,
          highlights,
          onHighlightTap: onHighlightTap,
          searchQuery: searchQuery,
          searchMatchHighlight: searchMatchHighlight,
          vocabularyWords: _effectiveVocabWords,
        );
        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < paragraphList.length - 1 ? paragraphSpacing : 0,
            ),
            child: SelectableText.rich(
              painted,
              strutStyle: strutStyle,
              textAlign: TextAlign.justify,
              onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                sel,
                paragraphList[index],
                offsets[index],
                context,
              ),
              contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalScrollMode(
    String content,
    Color textColor,
    ScrollController scrollController,
    ReaderRepository repo,
    BuildContext context,
  ) {
    final richSpan = repo.getCachedRichTextSpan(bookId, chapterId);
    final textStyle = FontConfig.readerStyle(
      fontSize: fontSize,
      lineHeight: lineHeight,
      color: textColor,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );
    final strutStyle = FontConfig.readerStrut(
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
    );
    final charWidth = fontSize * 1.2;

    if (richSpan != null) {
      final textParagraphs = _extractParagraphSpans(richSpan);
      if (textParagraphs.isEmpty) {
        return const Center(child: Text('内容为空'));
      }
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: adaptiveScrollPhysics(context),
          padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
          itemCount: textParagraphs.length,
          itemBuilder: (context, index) {
            final span = textParagraphs[index];
            final painted = HighlightPainter.paintRich(
              span, 0, highlights,
              onHighlightTap: onHighlightTap,
              vocabularyWords: _effectiveVocabWords,
            );
            return Padding(
              padding: EdgeInsets.only(left: index < textParagraphs.length - 1 ? paragraphSpacing : 0),
              child: SizedBox(
                width: charWidth,
                child: SelectableText.rich(
                  painted,
                  style: textStyle,
                  strutStyle: strutStyle,
                  textAlign: TextAlign.start,
                  onSelectionChanged: (sel, cause) => _onRichSelectionChanged(
                    sel, span, 0, context,
                  ),
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      );
    }

    final paragraphList = content.split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    if (paragraphList.isEmpty) {
      return const Center(child: Text('内容为空'));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        physics: adaptiveScrollPhysics(context),
        padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
        itemCount: paragraphList.length,
        itemBuilder: (context, index) {
          final painted = HighlightPainter.paintPlain(
            paragraphList[index], textStyle, highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: searchQuery,
            searchMatchHighlight: searchMatchHighlight,
            vocabularyWords: _effectiveVocabWords,
          );
          return Padding(
            padding: EdgeInsets.only(left: index < paragraphList.length - 1 ? paragraphSpacing : 0),
            child: SizedBox(
              width: charWidth,
              child: SelectableText.rich(
                painted,
                strutStyle: strutStyle,
                textAlign: TextAlign.start,
                onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                  sel, paragraphList[index], 0, context,
                ),
                contextMenuBuilder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRichScrollWithImages(
    List<RichParagraph> richParagraphs,
    TextSpan richSpan,
    TextStyle textStyle,
    StrutStyle strutStyle,
    ScrollController scrollController,
    BuildContext context,
  ) {
    final textParagraphs = _extractParagraphSpans(richSpan);
    var accOffset = 0;
    final paraOffsets = <int>[];
    for (final p in textParagraphs) {
      paraOffsets.add(accOffset);
      accOffset += _spanTextLength(p) + 2;
    }

    final textParaIndex = <int>[];
    var ti = 0;
    for (final rp in richParagraphs) {
      if (rp.isImage) {
        textParaIndex.add(-1);
      } else {
        textParaIndex.add(ti);
        ti++;
      }
    }

    final maxWidth = MediaQuery.of(context).size.width - 32;

    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
      itemCount: richParagraphs.length,
      itemBuilder: (context, index) {
        final rp = richParagraphs[index];
        if (rp.isImage) {
          if (rp.imageData.isEmpty) return const SizedBox.shrink();
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: DesignTokens.spacing(Spacing.sm),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  rp.imageData,
                  width: maxWidth,
                  fit: BoxFit.contain,
                  cacheWidth:
                      (maxWidth * MediaQuery.of(context).devicePixelRatio)
                          .ceil(),
                  errorBuilder: (_, e, s) => Container(
                    height: 100,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(
                        PhosphorIconsRegular.imageBroken,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          final textIdx = textParaIndex[index];
          if (textIdx < 0 || textIdx >= textParagraphs.length) {
            return const SizedBox.shrink();
          }
          final span = textParagraphs[textIdx];
          final offset = paraOffsets[textIdx];
          final painted = HighlightPainter.paintRich(
            span,
            offset,
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: searchQuery,
            searchMatchHighlight: searchMatchHighlight,
            vocabularyWords: _effectiveVocabWords,
          );
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: textIdx < textParagraphs.length - 1
                    ? paragraphSpacing
                    : 0,
              ),
              child: SelectableText.rich(
                painted,
                style: textStyle,
                strutStyle: strutStyle,
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) =>
                    _onRichSelectionChanged(sel, span, offset, context),
                contextMenuBuilder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          );
        }
      },
    );
  }

  void _reportSelectionPosition(BuildContext context, TextSelection sel) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionGlobalPosition?.call(null);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return;
    onSelectionGlobalPosition?.call(box.localToGlobal(Offset.zero));
  }

  void _onPlainSelectionChanged(
    TextSelection sel,
    String paragraphText,
    int offset, [
    BuildContext? buildContext,
  ]) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionChanged?.call('', 0, 0);
      return;
    }
    final start = sel.start;
    final end = sel.end;
    final text = paragraphText.substring(start, end);
    onSelectionChanged?.call(text, offset + start, offset + end);
    if (buildContext != null) {
      _reportSelectionPosition(buildContext, sel);
    }
  }

  void _onRichSelectionChanged(
    TextSelection sel,
    TextSpan span,
    int offset, [
    BuildContext? buildContext,
  ]) {
    if (!sel.isValid || sel.isCollapsed) {
      onSelectionChanged?.call('', 0, 0);
      return;
    }
    final fullText = span.toPlainText();
    if (sel.start >= fullText.length) {
      onSelectionChanged?.call('', 0, 0);
      return;
    }
    final end = sel.end > fullText.length ? fullText.length : sel.end;
    final text = fullText.substring(sel.start, end);
    onSelectionChanged?.call(text, offset + sel.start, offset + end);
    if (buildContext != null) {
      _reportSelectionPosition(buildContext, sel);
    }
  }

  int _spanTextLength(TextSpan span) {
    if (span.text != null) return span.text!.length;
    if (span.children != null) {
      var len = 0;
      for (final child in span.children!) {
        if (child is TextSpan) len += _spanTextLength(child);
      }
      return len;
    }
    return 0;
  }

  String _splitLongSentence(String text) {
    if (!showSentenceSplit || text.length < 80) return text;
    final buf = StringBuffer();
    final sentenceRegex = RegExp(r'[^.!?]+[.!?]');
    var start = 0;
    for (final m in sentenceRegex.allMatches(text)) {
      final sentence = m.group(0)!.trim();
      if (sentence.split(RegExp(r'\s+')).length > 40) {
        final clauses = sentence.split(RegExp(r'(?<=[,;:]) '));
        buf.writeln(clauses.join('\n  '));
      } else {
        buf.writeln(sentence);
      }
      start = m.end;
    }
    if (start < text.length) {
      buf.writeln(text.substring(start).trim());
    }
    var result = buf.toString().trim();
    if (result.endsWith('\n')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  Widget _buildPaginationMode(
    BuildContext context,
    String content,
    Color textColor,
    Color backgroundColor,
    PageController pageController,
    ReaderRepository repo,
  ) {
    final cachedPages = repo.getCachedPages(bookId, chapterId);
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
          final textStyle = FontConfig.readerStyle(
            fontSize: fontSize,
            lineHeight: lineHeight,
            color: textColor,
            fontFamily: fontFamily,
            letterSpacing: letterSpacing,
          );
          final strutStyle = FontConfig.readerStrut(
            fontSize: fontSize,
            lineHeight: lineHeight,
            fontFamily: fontFamily,
          );
          if (page.richContent != null) {
            final painted = HighlightPainter.paintRich(
              page.richContent!,
              page.startOffset,
              highlights,
              onHighlightTap: onHighlightTap,
              searchQuery: searchQuery,
              searchMatchHighlight: searchMatchHighlight,
              vocabularyWords: _effectiveVocabWords,
            );
            return RepaintBoundary(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: pageMargin,
                  vertical: 20,
                ),
                child: SelectableText.rich(
                  TextSpan(style: textStyle, children: [painted]),
                  strutStyle: strutStyle,
                  textAlign: TextAlign.justify,
                  onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                    sel,
                    page.content,
                    page.startOffset,
                    context,
                  ),
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ),
            );
          }
          final paintedSpan = HighlightPainter.paintPlain(
            page.content,
            textStyle,
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: searchQuery,
            searchMatchHighlight: searchMatchHighlight,
            vocabularyWords: _effectiveVocabWords,
          );
          return RepaintBoundary(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: pageMargin,
                vertical: 20,
              ),
              child: SelectableText.rich(
                paintedSpan,
                strutStyle: strutStyle,
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                  sel,
                  page.content,
                  page.startOffset,
                  context,
                ),
                contextMenuBuilder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      );
    }

    return _buildFallbackPagination(
      context,
      content,
      textColor,
      pageController,
    );
  }

  Widget _buildFallbackPagination(
    BuildContext context,
    String content,
    Color textColor,
    PageController pageController,
  ) {
    final charsPerPage = _estimateCharsPerPage();
    final pages = _paginateContent(content, charsPerPage);

    if (pages.isEmpty) {
      return const Center(child: Text('内容为空'));
    }

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
        final textStyle = FontConfig.readerStyle(
          fontSize: fontSize,
          lineHeight: lineHeight,
          color: textColor,
          fontFamily: fontFamily,
          letterSpacing: letterSpacing,
        );
        final strutStyle = FontConfig.readerStrut(
          fontSize: fontSize,
          lineHeight: lineHeight,
          fontFamily: fontFamily,
        );
        final painted = HighlightPainter.paintPlain(
          pageContent,
          textStyle,
          highlights,
          onHighlightTap: onHighlightTap,
          searchQuery: searchQuery,
          searchMatchHighlight: searchMatchHighlight,
          vocabularyWords: _effectiveVocabWords,
        );
        return RepaintBoundary(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
            child: SelectableText.rich(
              painted,
              strutStyle: strutStyle,
              textAlign: TextAlign.justify,
              onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                sel,
                pageContent,
                pageStart,
                context,
              ),
              contextMenuBuilder: (_, __) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBilingualMode(
    BuildContext context,
    Color textColor,
    Color backgroundColor,
    List<BilingualHighlightPair> bilingualPairs,
    ScrollController scrollController,
  ) {
    if (isBilingualLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bilingualError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              bilingualError!,
              style: TextStyle(fontSize: 16, color: textColor),
            ),
          ],
        ),
      );
    }
    final alignment = bilingualAlignment;
    if (alignment == null || alignment.segments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('无对照译文', style: TextStyle(fontSize: 16, color: textColor)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRequestTranslation,
              icon: const Icon(PhosphorIconsRegular.plus),
              label: const Text('设置译文'),
            ),
          ],
        ),
      );
    }

    final cnHighlights = highlights
        .where((h) => h.language == null || h.language == 'zh')
        .toList();
    final enHighlights = highlights.where((h) => h.language == 'en').toList();
    for (final pair in bilingualPairs) {
      if (pair.sourceNote.language == null ||
          pair.sourceNote.language == 'zh') {
        cnHighlights.add(pair.sourceNote);
      } else {
        enHighlights.add(pair.sourceNote);
      }
      final target = pair.targetNote;
      if (target != null) {
        if (target.language == null || target.language == 'zh') {
          cnHighlights.add(target);
        } else {
          enHighlights.add(target);
        }
      }
    }

    final chineseStyle = FontConfig.readerStyle(
      fontSize: fontSize,
      lineHeight: lineHeight,
      color: textColor,
      fontFamily: fontFamily,
      letterSpacing: letterSpacing,
    );
    final chineseStrut = FontConfig.readerStrut(
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
    );
    final englishStyle = FontConfig.readerStyle(
      fontSize: fontSize * 0.9,
      lineHeight: lineHeight,
      color: textColor.withAlpha(180),
      fontFamily: fontFamily,
      useLatin: true,
      letterSpacing: letterSpacing,
    );
    final englishStrut = FontConfig.readerStrut(
      fontSize: fontSize * 0.9,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
      useLatin: true,
    );

    final cnOffsets = <int>[];
    var acc = 0;
    for (final seg in alignment.segments) {
      cnOffsets.add(acc);
      acc += seg.chinese.length;
    }
    final enOffsets = <int>[];
    acc = 0;
    for (final seg in alignment.segments) {
      enOffsets.add(acc);
      acc += seg.english.length;
    }

    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(horizontal: pageMargin, vertical: 20),
      itemCount: alignment.segments.length,
      itemBuilder: (context, index) {
        final seg = alignment.segments[index];
        final cnOff = cnOffsets[index];
        final enOff = enOffsets[index];

        final cnSegHighlights = cnHighlights
            .where((h) {
              final hStart = h.charOffset.toInt();
              final hEnd = hStart + h.length.toInt();
              return hEnd > cnOff && hStart < cnOff + seg.chinese.length;
            })
            .map((h) => h.copyWith(charOffset: h.charOffset - cnOff))
            .toList();

        final cnSpan = HighlightPainter.paintPlain(
          seg.chinese,
          chineseStyle,
          cnSegHighlights,
          onHighlightTap: onHighlightTap,
          searchQuery: searchQuery,
          searchMatchHighlight: searchMatchHighlight,
          vocabularyWords: _effectiveVocabWords,
        );

        final enSegHighlights = enHighlights
            .where((h) {
              final hStart = h.charOffset.toInt();
              final hEnd = hStart + h.length.toInt();
              return hEnd > enOff && hStart < enOff + seg.english.length;
            })
            .map((h) => h.copyWith(charOffset: h.charOffset - enOff))
            .toList();

        final enSpan = HighlightPainter.paintPlain(
          seg.english,
          englishStyle,
          enSegHighlights,
          onHighlightTap: onHighlightTap,
          searchQuery: searchQuery,
          searchMatchHighlight: searchMatchHighlight,
          vocabularyWords: _effectiveVocabWords,
        );

        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText.rich(
                  cnSpan,
                  strutStyle: chineseStrut,
                  onSelectionChanged: (sel, cause) =>
                      _onPlainSelectionChanged(sel, seg.chinese, cnOff, context),
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: textColor.withAlpha(40),
                ),
                const SizedBox(height: 4),
                SelectableText.rich(
                  enSpan,
                  strutStyle: englishStrut,
                  onSelectionChanged: (sel, cause) =>
                      _onPlainSelectionChanged(sel, seg.english, enOff, context),
                  contextMenuBuilder: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _estimateCharsPerPage() {
    final width = 400.0;
    final height = 600.0;
    final availableWidth = width - 32;
    final availableHeight = height - 32;
    final charsPerLine = (availableWidth / fontSize).floor();
    final linesPerPage = (availableHeight / (fontSize * lineHeight)).floor();
    return (charsPerLine * linesPerPage).clamp(100, 5000);
  }

  List<String> _paginateContent(String content, int charsPerPage) {
    if (content.isEmpty) return [];

    final pages = <String>[];
    final totalChars = content.length;
    var offset = 0;

    while (offset < totalChars) {
      final endOffset = (offset + charsPerPage).clamp(0, totalChars);
      var actualEndOffset = endOffset;
      if (endOffset < totalChars) {
        final searchRange = content.substring(
          (endOffset - 100).clamp(0, totalChars),
          endOffset,
        );
        final lastNewline = searchRange.lastIndexOf('\n');
        if (lastNewline != -1) {
          actualEndOffset = (endOffset - 100) + lastNewline + 1;
        }
      }
      final pageContent = content.substring(offset, actualEndOffset);
      pages.add(pageContent);
      offset = actualEndOffset;
    }

    if (pages.isEmpty) {
      pages.add(content);
    }

    return pages;
  }

  int _findPageIndexForOffset(List<PageInfo> pages, int charOffset) {
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (charOffset >= page.startOffset && charOffset < page.endOffset) {
        return i;
      }
    }
    return pages.isEmpty ? 0 : pages.length - 1;
  }

  int _findFallbackPageStart(List<String> pages, int targetIndex) {
    var offset = 0;
    for (int i = 0; i < targetIndex && i < pages.length; i++) {
      offset += pages[i].length;
    }
    return offset;
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
