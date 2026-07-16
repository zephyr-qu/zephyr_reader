import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';

/// 与 [IrReaderIrBlock.buildHighlightedSpan] 同构的高度测量（WidgetSpan 首行缩进）。
///
/// 禁止再用「首行收窄宽度 + 分段累加」——那会系统性偏高，页底留白。
double measureRenderedSliceHeight({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required StrutStyle strutStyle,
  double firstLineIndentPx = 0,
}) {
  if (text.isEmpty) return 0;

  final InlineSpan span;
  if (firstLineIndentPx > 0) {
    span = TextSpan(
      style: style,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: firstLineIndentPx),
        ),
        TextSpan(text: text, style: style),
      ],
    );
  } else {
    span = TextSpan(text: text, style: style);
  }

  final tp = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout(maxWidth: maxWidth);
  return tp.height;
}
