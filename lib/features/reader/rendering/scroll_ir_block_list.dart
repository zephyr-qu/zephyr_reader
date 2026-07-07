import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/features/reader/rendering/block_page_content.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// P4-1：scroll 模式按 [ContentBlock] 流渲染（与 pagination 块分页同源 IR）。
Widget buildScrollIrBlockList({
  required BuildContext context,
  required ScrollController scrollController,
  required List<ContentBlock> blocks,
  required String? epubFilePath,
  required int chapterIndex,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  void Function(Note)? onHighlightTap,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
}) {
  final chapterHighlights = highlights
      .where((h) => h.chapterIndex.toInt() == chapterIndex)
      .toList();
  final imageMaxWidth = _scrollImageMaxWidth(context, config);
  final imageMaxHeight = _scrollImageMaxHeight(context);

  return ListView.builder(
    controller: scrollController,
    physics: adaptiveScrollPhysics(context),
    padding: EdgeInsets.symmetric(horizontal: config.pageMargin, vertical: 20),
    itemCount: blocks.length,
    itemBuilder: (context, index) {
      return buildScrollIrBlockItem(
        context: context,
        block: blocks[index],
        epubFilePath: epubFilePath,
        config: config,
        highlights: chapterHighlights,
        imageMaxWidth: imageMaxWidth,
        imageMaxHeight: imageMaxHeight,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
        addBottomSpacing: index < blocks.length - 1,
      );
    },
  );
}

/// 多章 IR 段拼接 ListView（Phase C）。
Widget buildScrollIrMultiSegmentList({
  required BuildContext context,
  required ScrollController scrollController,
  required List<ScrollChapterSegment> segments,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  void Function(Note)? onHighlightTap,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
}) {
  final items = <_IrSegmentItem>[];
  for (final seg in segments) {
    final blocks = seg.irBlocks;
    if (blocks == null || blocks.isEmpty) continue;
    for (var i = 0; i < blocks.length; i++) {
      items.add(
        _IrSegmentItem(
          chapterIndex: seg.chapterIndex,
          block: blocks[i],
          filePath: seg.chapterFilePath,
          addBottomSpacing: i < blocks.length - 1,
        ),
      );
    }
  }

  final imageMaxWidth = _scrollImageMaxWidth(context, config);
  final imageMaxHeight = _scrollImageMaxHeight(context);

  return ListView.builder(
    controller: scrollController,
    physics: adaptiveScrollPhysics(context),
    padding: EdgeInsets.symmetric(horizontal: config.pageMargin, vertical: 20),
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index];
      final chapterHighlights = highlights
          .where((h) => h.chapterIndex.toInt() == item.chapterIndex)
          .toList();
      return buildScrollIrBlockItem(
        context: context,
        block: item.block,
        epubFilePath: item.filePath,
        config: config,
        highlights: chapterHighlights,
        imageMaxWidth: imageMaxWidth,
        imageMaxHeight: imageMaxHeight,
        onHighlightTap: onHighlightTap,
        onSelectionChanged: onSelectionChanged,
        onSelectionGlobalPosition: onSelectionGlobalPosition,
        addBottomSpacing: item.addBottomSpacing,
      );
    },
  );
}

Widget buildScrollIrBlockItem({
  required BuildContext context,
  required ContentBlock block,
  required String? epubFilePath,
  required ReaderRenderConfig config,
  required List<Note> highlights,
  required double imageMaxWidth,
  required int imageMaxHeight,
  void Function(Note)? onHighlightTap,
  void Function(String text, int start, int end)? onSelectionChanged,
  void Function(Offset?)? onSelectionGlobalPosition,
  bool addBottomSpacing = false,
}) {
  final child = block.when(
    text: (tb) {
      if (tb.text.isEmpty) return const SizedBox.shrink();
      final offset = tb.plain.plainStart;
      final blockFontSize = IrTextBlockStyle.effectiveFontSize(
        tb.style,
        config,
      );
      final blockStrutStyle = config.buildStrutStyle(
        fontSizeMultiplier: blockFontSize / config.fontSize,
        lineHeight: IrTextBlockStyle.effectiveLineHeight(tb.style, config),
      );
      final textAlign = IrTextBlockStyle.resolveTextAlign(
        tb.style.textAlign,
        config.textAlign,
      );
      final painted = IrTextBlockStyle.buildHighlightedSpan(
        text: tb.text,
        spans: tb.spans,
        irStyle: tb.style,
        config: config,
        highlights: highlights,
        contentStart: offset,
        applyFirstLineIndent: true,
        onHighlightTap: onHighlightTap,
      );
      return SelectableText.rich(
        painted,
        strutStyle: blockStrutStyle,
        textAlign: textAlign,
        textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
        onSelectionChanged: (sel, cause) => _handleSelection(
          sel,
          tb.text,
          offset,
          context,
          onSelectionChanged,
          onSelectionGlobalPosition,
        ),
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      );
    },
    image: (ib) {
      final path = epubFilePath;
      if (path == null || path.isEmpty) {
        return const SizedBox.shrink();
      }
      return EpubBlockImage(
        filePath: path,
        assetId: ib.assetId,
        alt: ib.alt,
        maxWidthPx: imageMaxWidth.round(),
        maxHeightPx: imageMaxHeight,
      );
    },
  );

  final textBlockStyle = block.when(text: (tb) => tb.style, image: (_) => null);

  Widget wrapped = child;
  if (textBlockStyle != null) {
    wrapped = Padding(
      padding: IrTextBlockStyle.resolveBlockPadding(textBlockStyle, config),
      child: child,
    );
  }

  if (!addBottomSpacing) {
    return wrapped;
  }
  final bottomSpacing = textBlockStyle != null
      ? IrTextBlockStyle.resolveBottomSpacing(textBlockStyle, config)
      : (config.paragraphSpacing / 2).clamp(4, 16);
  if (bottomSpacing <= 0) {
    return wrapped;
  }
  return Padding(
    padding: EdgeInsets.only(bottom: bottomSpacing.toDouble()),
    child: wrapped,
  );
}

class _IrSegmentItem {
  const _IrSegmentItem({
    required this.chapterIndex,
    required this.block,
    required this.filePath,
    required this.addBottomSpacing,
  });

  final int chapterIndex;
  final ContentBlock block;
  final String? filePath;
  final bool addBottomSpacing;
}

double _scrollImageMaxWidth(BuildContext context, ReaderRenderConfig config) {
  return (MediaQuery.sizeOf(context).width - 2 * config.pageMargin).clamp(
    1.0,
    4096.0,
  );
}

int _scrollImageMaxHeight(BuildContext context) {
  return (MediaQuery.sizeOf(context).height * 0.65).round().clamp(1, 4096);
}

void _handleSelection(
  TextSelection sel,
  String blockText,
  int blockPlainStart,
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
  final text = blockText.substring(start, end);
  onSelectionChanged?.call(
    text,
    blockPlainStart + start,
    blockPlainStart + end,
  );
  if (onSelectionGlobalPosition != null) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.attached) {
      onSelectionGlobalPosition(box.localToGlobal(Offset.zero));
    }
  }
}
