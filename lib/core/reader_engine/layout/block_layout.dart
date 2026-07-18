import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart'
    show BlockStyle;

/// 一个 IR 块的完整行式布局结果。
///
/// ADR-018：行高必须来自真实 TextPainter 测量，非 fontSize×lineHeight×lineCount。
@immutable
class BlockLayout {
  final int blockIndex;
  final int startUtf16;
  final int endUtf16;
  final EdgeInsets margins;
  final BlockStyle? style;
  final List<LineLayout> lines;

  /// 图片块专用。
  final bool isImage;
  final String? assetId;
  final String? imageAlt;
  final int? intrinsicWidth;
  final int? intrinsicHeight;
  final double? imageDisplayWidth;
  final double? imageDisplayHeight;
  final bool isFullPage;

  const BlockLayout({
    required this.blockIndex,
    required this.startUtf16,
    required this.endUtf16,
    this.margins = EdgeInsets.zero,
    this.style,
    required this.lines,
    this.isImage = false,
    this.assetId,
    this.imageAlt,
    this.intrinsicWidth,
    this.intrinsicHeight,
    this.imageDisplayWidth,
    this.imageDisplayHeight,
    this.isFullPage = false,
  });

  double get contentHeight =>
      lines.fold(0.0, (sum, l) => sum + l.height) + margins.vertical;

  int get lineCount => lines.length;
}

/// 单行 UTF-16 范围 + 真实高度。
@immutable
class LineLayout {
  final int startUtf16;
  final int endUtf16;
  final double height;
  final double baseline;
  final bool hardBreak;

  const LineLayout({
    required this.startUtf16,
    required this.endUtf16,
    required this.height,
    required this.baseline,
    this.hardBreak = false,
  });
}
