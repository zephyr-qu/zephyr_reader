import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'highlight_painter.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'reader_render_config.dart';
import 'find_render_box.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';

/// 滚动模式渲染器。
///
/// 以连续滚动形式展示书籍内容，支持高亮显示和无限加载。
class ScrollModeRenderer extends HookWidget {
  final ReaderRenderConfig config;
  final ScrollController scrollController;
  final ReaderRenderDataSource dataSource;
  final String bookId;
  final int chapterId;
  final String content;
  final List<ScrollChapterSegment> segments;
  final int? segmentDividerIndex;
  final List<Note> highlights;
  final void Function(Note)? onHighlightTap;
  final void Function(String text, int start, int end)? onSelectionChanged;
  final void Function(Offset?)? onSelectionGlobalPosition;
  final bool showSentenceSplit;

  const ScrollModeRenderer({
    super.key,
    required this.config,
    required this.scrollController,
    required this.dataSource,
    required this.bookId,
    required this.chapterId,
    required this.content,
    this.segments = const [],
    this.segmentDividerIndex,
    required this.highlights,
    this.onHighlightTap,
    this.onSelectionChanged,
    this.onSelectionGlobalPosition,
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
    final richSpan = dataSource.currentRichContent;
    final paragraphList = useMemoized(
      () => content
          .split('\n\n')
          .where((p) => p.trim().isNotEmpty)
          .map((p) => _splitLongSentence(p))
          .toList(),
      [content],
    );
    final richParagraphs = dataSource.currentRichParagraphs;
    final richTextParagraphs = useMemoized(
      () => richSpan != null ? _extractParagraphSpans(richSpan) : null,
      [richSpan],
    );

    final hasSegments = segments.isNotEmpty;
    final segmentsHaveRich = hasSegments && segments.any((s) => s.isRich);

    if (hasSegments) {
      if (segmentsHaveRich) {
        return _buildMultiSegmentRichList(context, textStyle, strutStyle);
      }
      return _buildMultiSegmentPlainList(context, textStyle, strutStyle);
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
                textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                textAlign: config.textAlign,
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
              textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
              textAlign: config.textAlign,
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

  /// 多段富文本（EPUB/MD，含图片）拼接 ListView。
  Widget _buildMultiSegmentRichList(
    BuildContext context,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    final items = _flattenSegmentItems(segments);
    final chapterIds = segments.map((s) => s.chapterIndex).toSet();
    final segHighlights =
        highlights.where((h) => chapterIds.contains(h.chapterIndex.toInt())).toList();
    final maxWidth = _scrollImageMaxWidth(context);

    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final widget = item.imageParagraph != null
            ? _buildSegmentImageItem(item.imageParagraph!, maxWidth, context)
            : item.richSpan != null
                ? _buildSegmentRichTextItem(
                    context,
                    item,
                    segHighlights,
                    textStyle,
                    strutStyle,
                  )
                : _buildSegmentPlainTextItem(
                    context,
                    item,
                    segHighlights,
                    textStyle,
                    strutStyle,
                  );
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < items.length - 1 ? config.paragraphSpacing : 0,
          ),
          child: widget,
        );
      },
    );
  }

  List<_GlobalPara> _flattenPlainParagraphs(List<ScrollChapterSegment> segments) {
    final globalParagraphs = <_GlobalPara>[];
    for (var si = 0; si < segments.length; si++) {
      final seg = segments[si];
      for (var pi = 0; pi < seg.paragraphCount; pi++) {
        globalParagraphs.add(_GlobalPara(
          segIdx: si,
          localIdx: pi,
          text: seg.paragraphs[pi],
          startOffset: seg.paragraphCharOffsets[pi],
          isSegmentBoundary:
              pi == 0 && si > 0 && segments[si - 1].chapterIndex != seg.chapterIndex,
        ));
      }
    }
    return globalParagraphs;
  }

  List<_GlobalScrollItem> _flattenSegmentItems(List<ScrollChapterSegment> segments) {
    final items = <_GlobalScrollItem>[];
    for (var si = 0; si < segments.length; si++) {
      final seg = segments[si];
      final isBoundary =
          si > 0 && segments[si - 1].chapterIndex != seg.chapterIndex;
      if (seg.isRich) {
        items.addAll(_flattenRichSegment(seg, si, isBoundary));
      } else {
        for (var pi = 0; pi < seg.paragraphCount; pi++) {
          items.add(_GlobalScrollItem(
            segIdx: si,
            chapterIndex: seg.chapterIndex,
            charOffset: seg.paragraphCharOffsets[pi],
            plainText: seg.paragraphs[pi],
            isSegmentBoundary: isBoundary && pi == 0,
          ));
        }
      }
    }
    return items;
  }

  List<_GlobalScrollItem> _flattenRichSegment(
    ScrollChapterSegment seg,
    int segIdx,
    bool isBoundary,
  ) {
    final items = <_GlobalScrollItem>[];
    if (!seg.hasImages) {
      final spans = seg.richRootSpan != null
          ? _extractParagraphSpans(seg.richRootSpan!)
          : <TextSpan>[];
      var acc = 0;
      for (var i = 0; i < spans.length; i++) {
        final o = acc;
        acc += _spanTextLength(spans[i]) + 2;
        items.add(_GlobalScrollItem(
          segIdx: segIdx,
          chapterIndex: seg.chapterIndex,
          charOffset: o,
          richSpan: spans[i],
          isSegmentBoundary: isBoundary && i == 0,
        ));
      }
      return items;
    }

    final textParagraphs = seg.richRootSpan != null
        ? _extractParagraphSpans(seg.richRootSpan!)
        : <TextSpan>[];
    var accOffset = 0;
    final paraOffsets = <int>[];
    for (final p in textParagraphs) {
      paraOffsets.add(accOffset);
      accOffset += _spanTextLength(p) + 2;
    }
    var textIdx = 0;
    for (var li = 0; li < seg.richParagraphs!.length; li++) {
      final rp = seg.richParagraphs![li];
      if (rp.isImage) {
        final imgOffset =
            textIdx < paraOffsets.length ? paraOffsets[textIdx] : accOffset;
        items.add(_GlobalScrollItem(
          segIdx: segIdx,
          chapterIndex: seg.chapterIndex,
          charOffset: imgOffset,
          imageParagraph: rp,
          isSegmentBoundary: isBoundary && li == 0,
        ));
      } else {
        if (textIdx >= textParagraphs.length) {
          if (textIdx >= seg.paragraphs.length) continue;
          items.add(_GlobalScrollItem(
            segIdx: segIdx,
            chapterIndex: seg.chapterIndex,
            charOffset: seg.paragraphCharOffsets[textIdx],
            plainText: seg.paragraphs[textIdx],
            isSegmentBoundary: isBoundary && li == 0,
          ));
          textIdx++;
          continue;
        }
        items.add(_GlobalScrollItem(
          segIdx: segIdx,
          chapterIndex: seg.chapterIndex,
          charOffset: paraOffsets[textIdx],
          richSpan: textParagraphs[textIdx],
          isSegmentBoundary: isBoundary && li == 0,
        ));
        textIdx++;
      }
    }
    return items;
  }

  List<Note> _highlightsForParagraph(
    List<Note> segHighlights,
    int chapterIndex,
    int startOffset,
    int length,
  ) {
    final endOffset = startOffset + length;
    return segHighlights
        .where(
          (h) =>
              h.chapterIndex.toInt() == chapterIndex &&
              h.charOffset.toInt() < endOffset &&
              h.charOffset.toInt() + h.length.toInt() > startOffset,
        )
        .toList();
  }

  Widget _buildSegmentImageItem(
    RichParagraph rp,
    double maxWidth,
    BuildContext context,
  ) {
    if (rp.imageData.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Spacing.sm.value),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(
            rp.imageData,
            width: maxWidth,
            fit: BoxFit.contain,
            cacheWidth:
                (maxWidth * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
  }

  Widget _buildSegmentRichTextItem(
    BuildContext context,
    _GlobalScrollItem item,
    List<Note> segHighlights,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    final span = item.richSpan!;
    final painted = HighlightPainter.paintRich(
      span,
      item.charOffset,
      _highlightsForParagraph(
        segHighlights,
        item.chapterIndex,
        item.charOffset,
        _spanTextLength(span),
      ),
      onHighlightTap: onHighlightTap,
      vocabularyWords: config.effectiveVocabWords,
    );
    return RepaintBoundary(
      child: SelectableText.rich(
        painted,
        style: textStyle,
        strutStyle: strutStyle,
        textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
        textAlign: config.textAlign,
        onSelectionChanged: (sel, cause) =>
            _onRichSelectionChanged(sel, span, item.charOffset, context),
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSegmentPlainTextItem(
    BuildContext context,
    _GlobalScrollItem item,
    List<Note> segHighlights,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    final text = item.plainText ?? '';
    final painted = HighlightPainter.paintPlain(
      text,
      textStyle,
      _highlightsForParagraph(
        segHighlights,
        item.chapterIndex,
        item.charOffset,
        text.length,
      ),
      onHighlightTap: onHighlightTap,
      vocabularyWords: config.effectiveVocabWords,
    );
    return RepaintBoundary(
      child: SelectableText.rich(
        painted,
        strutStyle: strutStyle,
        textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
        textAlign: config.textAlign,
        onSelectionChanged: (sel, cause) =>
            _onPlainSelectionChanged(sel, text, item.charOffset, context),
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  /// 多段拼接纯文本 ListView。遍历 [segments] 所有段落，按全局段落索引构建连续滚动列表。
  Widget _buildMultiSegmentPlainList(
    BuildContext context,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    final globalParagraphs = _flattenPlainParagraphs(segments);
    final chapterIds = segments.map((s) => s.chapterIndex).toSet();
    final segHighlights =
        highlights.where((h) => chapterIds.contains(h.chapterIndex.toInt())).toList();

    return ListView.builder(
      controller: scrollController,
      physics: adaptiveScrollPhysics(context),
      padding: EdgeInsets.symmetric(
        horizontal: config.pageMargin,
        vertical: 20,
      ),
      itemCount: globalParagraphs.length,
      itemBuilder: (context, index) {
        final gp = globalParagraphs[index];
        final seg = segments[gp.segIdx];
        final paraHighlights = _highlightsForParagraph(
          segHighlights,
          seg.chapterIndex,
          gp.startOffset,
          gp.text.length,
        );
        final painted = HighlightPainter.paintPlain(
          gp.text,
          textStyle,
          paraHighlights,
          onHighlightTap: onHighlightTap,
          vocabularyWords: config.effectiveVocabWords,
        );
        final children = <Widget>[
          RepaintBoundary(
            child: SelectableText.rich(
              painted,
              strutStyle: strutStyle,
              textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
              textAlign: config.textAlign,
              onSelectionChanged: (sel, cause) => _onPlainSelectionChanged(
                sel,
                gp.text,
                gp.startOffset,
                context,
              ),
              contextMenuBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ];
        if (gp.isSegmentBoundary && segmentDividerIndex == index) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                color: config.textColor.withAlpha(24),
                height: 1,
              ),
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < globalParagraphs.length - 1
                ? config.paragraphSpacing
                : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
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

    final maxWidth = _scrollImageMaxWidth(context);

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
              padding: EdgeInsets.symmetric(vertical: Spacing.sm.value),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(
                  rp.imageData,
                  width: maxWidth,
                  fit: BoxFit.contain,
                  cacheWidth:
                      (maxWidth * MediaQuery.devicePixelRatioOf(context))
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
                textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
                textAlign: config.textAlign,
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

  double _scrollImageMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return (width - 2 * config.pageMargin).clamp(1.0, width);
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
    final box = findRenderBox(context);
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

/// 全局段落辅助结构。
class _GlobalPara {
  final int segIdx;
  final int localIdx;
  final String text;
  final int startOffset;
  final bool isSegmentBoundary;

  const _GlobalPara({
    required this.segIdx,
    required this.localIdx,
    required this.text,
    required this.startOffset,
    required this.isSegmentBoundary,
  });
}

/// 多段滚动列表项（plain / rich / image）。
class _GlobalScrollItem {
  final int segIdx;
  final int chapterIndex;
  final int charOffset;
  final bool isSegmentBoundary;
  final String? plainText;
  final TextSpan? richSpan;
  final RichParagraph? imageParagraph;

  const _GlobalScrollItem({
    required this.segIdx,
    required this.chapterIndex,
    required this.charOffset,
    this.isSegmentBoundary = false,
    this.plainText,
    this.richSpan,
    this.imageParagraph,
  });
}
