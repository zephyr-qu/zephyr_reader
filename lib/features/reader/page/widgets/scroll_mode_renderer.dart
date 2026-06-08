import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import '../../data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/page/widgets/highlight_painter.dart';
import 'reader_render_config.dart';

/// 滚动模式渲染器。
///
/// 以连续滚动形式展示书籍内容，支持高亮显示和无限加载。
class ScrollModeRenderer extends HookWidget {
  final ReaderRenderConfig config;
  final ScrollController scrollController;
  final ReaderRepository repo;
  final String bookId;
  final int chapterId;
  final String content;
  final List<Note> highlights;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final void Function(Offset?)? onSelectionGlobalPosition;
  final WritingDirection writingDirection;
  final bool showSentenceSplit;

  const ScrollModeRenderer({
    super.key,
    required this.config,
    required this.scrollController,
    required this.repo,
    required this.bookId,
    required this.chapterId,
    required this.content,
    required this.highlights,
    this.onHighlightTap,
    this.onSelectionChanged,
    this.onSelectionGlobalPosition,
    required this.writingDirection,
    this.showSentenceSplit = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = useMemoized(() => config.buildTextStyle(), [
      config.fontSize,
      config.lineHeight,
      config.textColor,
      config.fontFamily,
      config.letterSpacing,
    ]);
    final strutStyle = useMemoized(() => config.buildStrutStyle(), [
      config.fontSize,
      config.lineHeight,
      config.fontFamily,
    ]);
    final richSpan = repo.currentRichContent;
    final paragraphList = useMemoized(
      () => content
          .split('\n\n')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => _splitLongSentence(p))
          .toList(),
      [content],
    );
    final richParagraphs = repo.currentRichParagraphs;
    final richTextParagraphs = useMemoized(
      () => richSpan != null ? _extractParagraphSpans(richSpan) : null,
      [richSpan],
    );

    if (writingDirection == WritingDirection.vertical) {
      return _buildVerticalScrollMode(
        context,
        textStyle,
        strutStyle,
        paragraphList,
        richTextParagraphs,
      );
    }

    if (richParagraphs != null && richParagraphs.any((p) => p.isImage)) {
      return _buildRichScrollWithImages(
        richParagraphs,
        richSpan!,
        textStyle,
        strutStyle,
        scrollController,
        context,
      );
    }

    if (richTextParagraphs != null && richTextParagraphs.isNotEmpty) {
      final paragraphs = richTextParagraphs;
      var accOffset = 0;
      final paraOffsets = paragraphs.map((p) {
        final o = accOffset;
        accOffset += _spanTextLength(p) + 2;
        return o;
      }).toList();
      return ListView.builder(
        controller: scrollController,
        physics: adaptiveScrollPhysics(context),
        padding: EdgeInsets.symmetric(
          horizontal: config.pageMargin,
          vertical: 20,
        ),
        itemCount: paragraphs.length,
        itemBuilder: (context, index) {
          final painted = HighlightPainter.paintRich(
            paragraphs[index],
            paraOffsets[index],
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: config.searchQuery,
            searchMatchHighlight: config.searchMatchHighlight,
            vocabularyWords: config.effectiveVocabWords,
          );
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: index < paragraphs.length - 1
                    ? config.paragraphSpacing
                    : 0,
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
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          );
        },
      );
    }

    // Fallback: plain text content
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
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
      itemCount: paragraphList.length,
      itemBuilder: (context, index) {
        final painted = HighlightPainter.paintPlain(
          paragraphList[index],
          textStyle,
          highlights,
          onHighlightTap: onHighlightTap,
          searchQuery: config.searchQuery,
          searchMatchHighlight: config.searchMatchHighlight,
          vocabularyWords: config.effectiveVocabWords,
        );
        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index < paragraphList.length - 1
                  ? config.paragraphSpacing
                  : 0,
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
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerticalScrollMode(
    BuildContext context,
    TextStyle textStyle,
    StrutStyle strutStyle,
    List<String> paragraphList,
    List<TextSpan>? richTextParagraphs,
  ) {
    final charWidth = config.fontSize * 1.2;

    if (richTextParagraphs != null && richTextParagraphs.isNotEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: adaptiveScrollPhysics(context),
          padding: EdgeInsets.symmetric(
            horizontal: config.pageMargin,
            vertical: 20,
          ),
          itemCount: richTextParagraphs.length,
          itemBuilder: (context, index) {
            final span = richTextParagraphs[index];
            final painted = HighlightPainter.paintRich(
              span,
              0,
              highlights,
              onHighlightTap: onHighlightTap,
              vocabularyWords: config.effectiveVocabWords,
            );
            return Padding(
              padding: EdgeInsets.only(
                left: index < richTextParagraphs.length - 1
                    ? config.paragraphSpacing
                    : 0,
              ),
              child: SizedBox(
                width: charWidth,
                child: SelectableText.rich(
                  painted,
                  style: textStyle,
                  strutStyle: strutStyle,
                  textAlign: TextAlign.start,
                  onSelectionChanged: (sel, cause) =>
                      _onRichSelectionChanged(sel, span, 0, context),
                  contextMenuBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ),
            );
          },
        ),
      );
    }

    // Fallback: plain text vertical mode
    if (paragraphList.isEmpty) {
      return const Center(child: Text('内容为空'));
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        controller: scrollController,
        physics: adaptiveScrollPhysics(context),
        padding: EdgeInsets.symmetric(
          horizontal: config.pageMargin,
          vertical: 20,
        ),
        itemCount: paragraphList.length,
        itemBuilder: (context, index) {
          final painted = HighlightPainter.paintPlain(
            paragraphList[index],
            textStyle,
            highlights,
            onHighlightTap: onHighlightTap,
            searchQuery: config.searchQuery,
            searchMatchHighlight: config.searchMatchHighlight,
            vocabularyWords: config.effectiveVocabWords,
          );
          return Padding(
            padding: EdgeInsets.only(
              left: index < paragraphList.length - 1
                  ? config.paragraphSpacing
                  : 0,
            ),
            child: SizedBox(
              width: charWidth,
              child: SelectableText.rich(
                painted,
                strutStyle: strutStyle,
                textAlign: TextAlign.start,
                onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                  sel,
                  paragraphList[index],
                  0,
                  context,
                ),
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
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

    final maxWidth = MediaQuery.sizeOf(context).width - 32;

    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
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
            searchQuery: config.searchQuery,
            searchMatchHighlight: config.searchMatchHighlight,
            vocabularyWords: config.effectiveVocabWords,
          );
          return RepaintBoundary(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: textIdx < textParagraphs.length - 1
                    ? config.paragraphSpacing
                    : 0,
              ),
              child: SelectableText.rich(
                painted,
                style: textStyle,
                strutStyle: strutStyle,
                textAlign: TextAlign.justify,
                onSelectionChanged: (sel, cause) =>
                    _onRichSelectionChanged(sel, span, offset, context),
                contextMenuBuilder: (_, _) => const SizedBox.shrink(),
              ),
            ),
          );
        }
      },
    );
  }

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
}
