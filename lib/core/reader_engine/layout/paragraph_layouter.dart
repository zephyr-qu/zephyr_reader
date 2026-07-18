import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 使用真实 TextPainter 生成不可变 BlockLayout。
///
/// ADR-018：行高必须来自 computeLineMetrics()，非 fontSize×lineHeight 估算。
class ParagraphLayouter {
  final SpanFactory spanFactory;
  final LayoutSpec spec;

  const ParagraphLayouter(this.spanFactory, this.spec);

  /// 布局一个文本段，返回带真实行高的 BlockLayout。
  BlockLayout layoutTextBlock({
    required int blockIndex,
    required String text,
    required List<ReaderInlineRun> spans,
    required BlockStyle style,
    required double maxWidth,
    double firstLineIndentPx = 0,
    int plainStart = 0,
  }) {
    if (text.isEmpty) {
      return BlockLayout(
        blockIndex: blockIndex,
        startUtf16: 0,
        endUtf16: 0,
        lines: const <LineLayout>[],
      );
    }

    final blockTextStyle = spanFactory.blockTextStyle(style);
    final strutStyle = spanFactory.blockStrutStyle(style);
    final layoutWidth = (maxWidth - spanFactory.blockPadding(style).horizontal)
        .clamp(1.0, maxWidth);

    final hasIndent = firstLineIndentPx > 0;
    final layoutSpan = hasIndent
        ? TextSpan(
            style: blockTextStyle,
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: SizedBox(width: firstLineIndentPx),
              ),
              spanFactory.buildSpan(text: text, spans: spans, style: style),
            ],
          )
        : spanFactory.buildSpan(text: text, spans: spans, style: style);

    final tp = TextPainter(
      text: layoutSpan,
      textDirection: spec.textDirection,
      strutStyle: strutStyle,
      textScaler: spec.textScaler,
      textHeightBehavior: spec.textHeightBehavior,
    );

    if (hasIndent) {
      tp.setPlaceholderDimensions([
        PlaceholderDimensions(
          size: Size(firstLineIndentPx, 0),
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          baselineOffset: 0,
        ),
      ]);
    }

    tp.layout(maxWidth: layoutWidth);
    final metrics = tp.computeLineMetrics();

    final lines = <LineLayout>[];
    // ponytail: single-pass; caller (packChunk) tracks page budget via line heights.
    for (var i = 0; i < metrics.length; i++) {
      final m = metrics[i];
      final centerY = m.baseline - m.ascent + m.ascent / 2;
      final centerX = m.left + m.width / 2;
      final pos = tp.getPositionForOffset(Offset(centerX, centerY));
      final boundary = tp.getLineBoundary(pos);
      final start = boundary.start - (hasIndent ? 1 : 0);
      final end = boundary.end - (hasIndent ? 1 : 0);

      lines.add(
        LineLayout(
          startUtf16: start.clamp(0, text.length),
          endUtf16: end.clamp(0, text.length),
          height: m.height,
          baseline: m.baseline,
          hardBreak: i + 1 < metrics.length,
        ),
      );
    }

    return BlockLayout(
      blockIndex: blockIndex,
      startUtf16: plainStart,
      endUtf16: plainStart + text.length,
      margins: spanFactory.blockPadding(style),
      style: style,
      lines: lines,
    );
  }

  /// 布局图片块。
  BlockLayout layoutImageBlock({
    required int blockIndex,
    required int startUtf16,
    required int endUtf16,
    required String assetId,
    String? imageAlt,
    int? intrinsicWidth,
    int? intrinsicHeight,
    double? imageDisplayWidth,
    double? imageDisplayHeight,
    bool isFullPage = false,
  }) {
    return BlockLayout(
      blockIndex: blockIndex,
      startUtf16: startUtf16,
      endUtf16: endUtf16,
      lines: const <LineLayout>[],
      isImage: true,
      assetId: assetId,
      imageAlt: imageAlt,
      intrinsicWidth: intrinsicWidth,
      intrinsicHeight: intrinsicHeight,
      imageDisplayWidth: imageDisplayWidth,
      imageDisplayHeight: imageDisplayHeight,
      isFullPage: isFullPage,
    );
  }
}
