/// 行断点索引提取——用 TextPainter 获取 Flutter 引擎 ICU 断行的精确结果。
///
/// # Ground Truth
///
/// Flutter 的 `TextPainter` 不直接暴露每行的字符索引。通过
/// `computeLineMetrics` + `getPositionForOffset` + `getLineBoundary`
/// 可得到与渲染引擎一致的行末偏移。
///
/// # Rust 对接格式
///
/// 返回章级绝对字符索引（每行结束偏移，半开上界语义与 TextPainter 一致）。
/// 优先按 **IR 文本块** 分别测量（与 `buildBlockPageContent` 同构），再合并；
/// 图片块写入 `\uFFFC` 结束位置，供 Rust 按图高装箱。
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 使用 TextPainter 从单段文本提取行断点（相对 [text] 起点）。
///
/// [firstLineIndentPx] > 0 时与 [measureSliceLayout] / 分页渲染一致：
/// 首行在收窄宽度下断行，续行用满宽。
List<int> computeLineBreakIndices({
  required String text,
  required TextStyle style,
  required double maxWidth,
  StrutStyle? strutStyle,
  double firstLineIndentPx = 0,
  TextScaler textScaler = TextScaler.noScaling,
  InlineSpan? textSpan,
}) {
  if (text.isEmpty) return [];
  final contentSpan = textSpan ?? TextSpan(text: text, style: style);
  final hasIndent = firstLineIndentPx > 0;
  final layoutSpan = hasIndent
      ? TextSpan(
          style: style,
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: firstLineIndentPx),
            ),
            contentSpan,
          ],
        )
      : contentSpan;
  return _lineBreakIndicesSimple(
    text: text,
    style: style,
    maxWidth: maxWidth,
    strutStyle: strutStyle,
    textScaler: textScaler,
    textSpan: layoutSpan,
    placeholderOffset: hasIndent ? 1 : 0,
    placeholderWidth: hasIndent ? firstLineIndentPx : 0,
  );
}

List<int> _lineBreakIndicesSimple({
  required String text,
  required TextStyle style,
  required double maxWidth,
  StrutStyle? strutStyle,
  TextScaler textScaler = TextScaler.noScaling,
  InlineSpan? textSpan,
  int placeholderOffset = 0,
  double placeholderWidth = 0,
}) {
  if (text.isEmpty) return [];

  final tp = TextPainter(
    text: textSpan ?? TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textScaler: textScaler,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  );
  if (placeholderOffset > 0) {
    tp.setPlaceholderDimensions([
      PlaceholderDimensions(
        size: Size(placeholderWidth, 0),
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        baselineOffset: 0,
      ),
    ]);
  }
  tp.layout(maxWidth: maxWidth);

  final metrics = tp.computeLineMetrics();
  final indices = <int>[];

  for (final line in metrics) {
    final centerY = line.baseline - line.ascent + line.ascent / 2;
    final centerX = line.left + line.width / 2;
    final pos = tp.getPositionForOffset(Offset(centerX, centerY));
    final boundary = tp.getLineBoundary(pos);
    final end = (boundary.end - placeholderOffset).clamp(0, text.length);
    if (end > 0 && (indices.isEmpty || indices.last != end)) {
      indices.add(end);
    }
  }

  return indices;
}

/// 按 IR 块分别 ICU 断行，合并为章级绝对行末索引。
///
/// [contentMaxWidth] 为正文可用宽（通常 `pageWidth - 2 * pageMargin`），
/// 与分页 `LayoutBuilder` 约束对齐。
List<int> computeChapterLineBreakIndicesFromBlocks({
  required List<ReaderIrBlock> blocks,
  required ReaderRenderConfig config,
  required double contentMaxWidth,
}) {
  if (blocks.isEmpty) return [];

  final maxWidth = contentMaxWidth.clamp(1.0, double.infinity);
  final indices = <int>[];

  for (final block in blocks) {
    if (block.kind == ReaderIrBlockKind.image) {
      // 图片在 plain 中占 1 个 \uFFFC；作为单行交给 Rust 按图高装箱。
      indices.add(block.plainStart + block.plainLen);
      continue;
    }
    if (block.text.isEmpty) continue;

    final blockFontSize = IrReaderIrBlock.effectiveFontSize(
      block.style,
      config,
    );
    final blockLineHeight = IrReaderIrBlock.effectiveLineHeight(
      block.style,
      config,
    );
    final textStyle = config
        .buildTextStyle(fontSizeMultiplier: blockFontSize / config.fontSize)
        .copyWith(height: blockLineHeight);
    final indentPx = IrReaderIrBlock.resolveFirstLineIndentPx(
      block.style,
      config,
    );
    final blockPadding = IrReaderIrBlock.resolveBlockPadding(
      block.style,
      config,
    );
    final layoutMaxWidth = (maxWidth - blockPadding.horizontal).clamp(
      1.0,
      maxWidth,
    );
    final strutStyle = config.buildStrutStyle(
      fontSizeMultiplier: blockFontSize / config.fontSize,
      lineHeight: blockLineHeight,
    );
    final local = computeLineBreakIndices(
      text: block.text,
      style: textStyle,
      maxWidth: layoutMaxWidth,
      strutStyle: strutStyle,
      firstLineIndentPx: indentPx,
      textScaler: config.textScaler,
      textSpan: IrReaderIrBlock.buildLayoutSpan(
        text: block.text,
        spans: block.runs,
        irStyle: block.style,
        config: config,
      ),
    );
    for (final end in local) {
      indices.add(block.plainStart + end);
    }
  }

  indices.sort();
  // 去重（极端情况下相邻块边界可能重合）
  final deduped = <int>[];
  for (final i in indices) {
    if (deduped.isEmpty || deduped.last != i) {
      deduped.add(i);
    }
  }
  return deduped;
}

/// 验证行断点索引的有效性。
///
/// 检查所有索引是否：
/// - 严格递增
/// - 最后一个索引 == [text].length（章级 plain 路径）
bool validateLineBreakIndices(List<int> indices, String text) {
  if (indices.isEmpty) return text.isEmpty;

  if (indices.length > 1) {
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] <= indices[i - 1]) return false;
    }
  }

  if (indices.last != text.length) return false;

  return true;
}

/// 为测量构造最小 [ReaderRenderConfig]（颜色无关）。
ReaderRenderConfig lineBreakMeasureRenderConfig({
  required double fontSize,
  required double lineHeight,
  required String fontFamily,
  required double letterSpacing,
  required double paragraphSpacing,
  required double pageMargin,
  required bool firstLineIndent,
  required bool baselineAlign,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ReaderRenderConfig(
    textColor: const Color(0xFF000000),
    backgroundColor: const Color(0xFFFFFFFF),
    fontSize: fontSize,
    lineHeight: lineHeight,
    fontFamily: fontFamily,
    letterSpacing: letterSpacing,
    paragraphSpacing: paragraphSpacing,
    pageMargin: pageMargin,
    showVocabularyMark: false,
    vocabularyWords: const {},
    firstLineIndent: firstLineIndent,
    baselineAlign: baselineAlign,
    textScaler: textScaler,
  );
}
