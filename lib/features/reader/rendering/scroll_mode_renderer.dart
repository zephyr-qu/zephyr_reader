import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'highlight_painter.dart';


import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'reader_render_config.dart';
import 'find_render_box.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'scroll_ir_block_list.dart';

/// 滚动模式渲染器。
///
/// 以连续滚动形式展示书籍内容，支持高亮显示和无限加载。
class ScrollModeRenderer extends HookWidget {
  final ReaderRenderConfig config;
  final ScrollController scrollController;
  final ReaderRenderDataSource dataSource;
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

    final chapterIr = dataSource.currentChapterIr;
    final hasSegments = segments.isNotEmpty;

    if (hasSegments && segments.every((s) => s.isIr)) {
      return buildScrollIrMultiSegmentList(
        context: context,
        scrollController: scrollController,
        segments: segments,
        config: config,
        highlights: highlights,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
      );
    }

    if (!hasSegments && chapterIr != null && chapterIr.blocks.isNotEmpty) {
      return buildScrollIrBlockList(
        context: context,
        scrollController: scrollController,
        blocks: chapterIr.blocks,
        epubFilePath: dataSource.currentChapterFilePath,
        chapterIndex: chapterId,
        config: config,
        highlights: highlights,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
      );
    }

    if (hasSegments) {
      return _buildMultiSegmentPlainList(context, textStyle, strutStyle);
    }

    // Fallback: plain text content（IR 未命中时）
    // IR 未命中——此路径不应被触发，出现则表示上游 IR 加载失败。
    debugPrint(
      '[ScrollModeRenderer] WARNING: IR unavailable, falling back to plain text. '
      'hasSegments=$hasSegments chapterIr=${chapterIr != null} blocks=${chapterIr?.blocks.length ?? 0}',
    );
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

  List<_GlobalPara> _flattenPlainParagraphs(
    List<ScrollChapterSegment> segments,
  ) {
    final globalParagraphs = <_GlobalPara>[];
    for (var si = 0; si < segments.length; si++) {
      final seg = segments[si];
      for (var pi = 0; pi < seg.paragraphs.length; pi++) {
        globalParagraphs.add(
          _GlobalPara(
            segIdx: si,
            localIdx: pi,
            text: seg.paragraphs[pi],
            startOffset: seg.paragraphCharOffsets[pi],
            isSegmentBoundary:
                pi == 0 &&
                si > 0 &&
                segments[si - 1].chapterIndex != seg.chapterIndex,
          ),
        );
      }
    }
    return globalParagraphs;
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

  /// 多段拼接纯文本 ListView。遍历 [segments] 所有段落，按全局段落索引构建连续滚动列表。
  Widget _buildMultiSegmentPlainList(
    BuildContext context,
    TextStyle textStyle,
    StrutStyle strutStyle,
  ) {
    final globalParagraphs = _flattenPlainParagraphs(segments);
    final chapterIds = segments.map((s) => s.chapterIndex).toSet();
    final segHighlights = highlights
        .where((h) => chapterIds.contains(h.chapterIndex.toInt()))
        .toList();

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
          contentStart: gp.startOffset,
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
              child: Divider(color: config.textColor.withAlpha(24), height: 1),
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
