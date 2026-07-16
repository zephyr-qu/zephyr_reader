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
import 'package:zephyr_reader/reader_engine/rendering/ir_text_block_style.dart';
import 'package:zephyr_reader/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';

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
}) {
  if (text.isEmpty) return [];

  if (firstLineIndentPx <= 0) {
    return _lineBreakIndicesSimple(
      text: text,
      style: style,
      maxWidth: maxWidth,
      strutStyle: strutStyle,
    );
  }

  final narrowWidth = (maxWidth - firstLineIndentPx).clamp(1.0, maxWidth);
  var firstLineChars = text.length;
  final probe = TextPainter(
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  );
  for (var n = 1; n <= text.length; n++) {
    probe.text = TextSpan(text: text.substring(0, n), style: style);
    probe.layout(maxWidth: narrowWidth);
    if (probe.computeLineMetrics().length > 1) {
      firstLineChars = n - 1;
      break;
    }
  }
  if (firstLineChars <= 0) {
    firstLineChars = 1;
  }

  if (firstLineChars >= text.length) {
    return _lineBreakIndicesSimple(
      text: text,
      style: style,
      maxWidth: narrowWidth,
      strutStyle: strutStyle,
    );
  }

  final first = _lineBreakIndicesSimple(
    text: text.substring(0, firstLineChars),
    style: style,
    maxWidth: narrowWidth,
    strutStyle: strutStyle,
  );
  final rest = _lineBreakIndicesSimple(
    text: text.substring(firstLineChars),
    style: style,
    maxWidth: maxWidth,
    strutStyle: strutStyle,
  );
  return [...first, ...rest.map((i) => i + firstLineChars)];
}

List<int> _lineBreakIndicesSimple({
  required String text,
  required TextStyle style,
  required double maxWidth,
  StrutStyle? strutStyle,
}) {
  if (text.isEmpty) return [];

  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout(maxWidth: maxWidth);

  final metrics = tp.computeLineMetrics();
  final indices = <int>[];

  for (final line in metrics) {
    final centerY = line.baseline - line.ascent + line.ascent / 2;
    final centerX = line.left + line.width / 2;
    final pos = tp.getPositionForOffset(Offset(centerX, centerY));
    final boundary = tp.getLineBoundary(pos);
    indices.add(boundary.end);
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

    final blockFontSize = IrReaderIrBlock.effectiveFontSize(block, config);
    final blockLineHeight = IrReaderIrBlock.effectiveLineHeight(block, config);
    final textStyle = config
        .buildTextStyle(fontSizeMultiplier: blockFontSize / config.fontSize)
        .copyWith(height: blockLineHeight);
    final indentPx =
        IrReaderIrBlock.resolveFirstLineIndentPx(block, config);
    final blockPadding = IrReaderIrBlock.resolveBlockPadding(block, config);
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
  );
}
