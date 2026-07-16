import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_chapter_segment.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/block_page_content.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// scroll 模式按 [ReaderIrBlock] 流渲染（与 pagination 块分页同源 IR）。
Widget buildScrollIrBlockList({
  required BuildContext context,
  required ScrollController scrollController,
  required List<ReaderIrBlock> blocks,
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
  required ReaderIrBlock block,
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
  Widget child;
  if (block.kind == ReaderIrBlockKind.text) {
    if (block.text.isEmpty) {
      child = const SizedBox.shrink();
    } else {
      final offset = block.plainStart;
      final blockFontSize = IrReaderIrBlock.effectiveFontSize(block, config);
      final blockStrutStyle = config.buildStrutStyle(
        fontSizeMultiplier: blockFontSize / config.fontSize,
        lineHeight: IrReaderIrBlock.effectiveLineHeight(block, config),
      );
      final textAlign = IrReaderIrBlock.resolveTextAlign(
        block.textAlign,
        config.textAlign,
      );
      final painted = IrReaderIrBlock.buildHighlightedSpan(
        text: block.text,
        spans: block.runs,
        irStyle: block,
        config: config,
        highlights: highlights,
        contentStart: offset,
        applyFirstLineIndent: true,
        onHighlightTap: onHighlightTap,
      );
      child = SelectableText.rich(
        painted,
        strutStyle: blockStrutStyle,
        textAlign: textAlign,
        textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
        onSelectionChanged: (sel, cause) => _handleSelection(
          sel,
          block.text,
          offset,
          context,
          onSelectionChanged,
          onSelectionGlobalPosition,
        ),
        contextMenuBuilder: (_, _) => const SizedBox.shrink(),
      );
    }
  } else {
    // Image block
    final path = epubFilePath;
    if (path == null || path.isEmpty) {
      child = const SizedBox.shrink();
    } else {
      child = EpubBlockImage(
        filePath: path,
        assetId: block.imageAssetId ?? '',
        alt: block.imageAlt?.isNotEmpty == true ? block.imageAlt : null,
        maxWidthPx: imageMaxWidth.round(),
        maxHeightPx: imageMaxHeight,
      );
    }
  }

  Widget wrapped = child;
  if (block.kind == ReaderIrBlockKind.text) {
    wrapped = Padding(
      padding: IrReaderIrBlock.resolveBlockPadding(block, config),
      child: child,
    );
  }

  if (!addBottomSpacing) {
    return wrapped;
  }
  final bottomSpacing = block.kind == ReaderIrBlockKind.text
      ? IrReaderIrBlock.resolveBottomSpacing(block, config)
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
  final ReaderIrBlock block;
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
