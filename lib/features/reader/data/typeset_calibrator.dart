import 'package:flutter/material.dart';

import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';

/// TextPainter 不支持 WidgetSpan；用首行缩进宽度模拟与渲染一致的行数/高度。
///
/// 与 [buildBlockPageContent] 诊断及 CI 对齐测试共用，避免双份实现漂移。
({int lines, double height}) measureSliceLayout({
  required String text,
  required TextStyle style,
  required double maxWidth,
  StrutStyle? strutStyle,
  double firstLineIndentPx = 0,
}) {
  if (text.isEmpty) {
    return (lines: 0, height: 0.0);
  }

  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  );

  if (firstLineIndentPx <= 0) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: maxWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  final narrowWidth = (maxWidth - firstLineIndentPx).clamp(1.0, maxWidth);
  var firstLineChars = text.length;
  for (var n = 1; n <= text.length; n++) {
    tp.text = TextSpan(text: text.substring(0, n), style: style);
    tp.layout(maxWidth: narrowWidth);
    if (tp.computeLineMetrics().length > 1) {
      firstLineChars = n - 1;
      break;
    }
  }
  if (firstLineChars <= 0) {
    firstLineChars = 1;
  }

  if (firstLineChars >= text.length) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: narrowWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  tp.text = TextSpan(text: text.substring(0, firstLineChars), style: style);
  tp.layout(maxWidth: narrowWidth);
  final firstHeight = tp.height;

  final remainder = text.substring(firstLineChars);
  tp.text = TextSpan(text: remainder, style: style);
  tp.layout(maxWidth: maxWidth);
  return (
    lines: 1 + tp.computeLineMetrics().length,
    height: firstHeight + tp.height,
  );
}


