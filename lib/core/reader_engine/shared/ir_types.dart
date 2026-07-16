/// 纯 Dart 侧 IR 类型（替代 FRB `pipeline/types.dart`）。
///
/// 这些类型在 Rust→Dart 边界处由 [`ChapterContentRepository`] 从 FRB 类型转换而来，
/// 下游代码不再依赖 FRB 序列化。
library;

import 'dart:ui' show TextAlign;

// ==================== 行内样式 ====================

/// 行内 span 样式。
enum ReaderInlineStyle { plain, bold, italic }

// ==================== 行内运行 ====================

/// 扁平的行内运行。
class ReaderInlineRun {
  final String text;
  final ReaderInlineStyle style;
  final String? url;

  const ReaderInlineRun({required this.text, required this.style, this.url});
}

// ==================== IR 块 ====================

/// IR 块类型枚举。
enum ReaderIrBlockKind { text, image }

/// 扁平的 IR 块。
class ReaderIrBlock {
  final ReaderIrBlockKind kind;
  final int plainStart;
  final int plainLen;
  final String text;
  final List<ReaderInlineRun> runs;
  final bool isHeading;
  final int headingLevel;
  final double? textIndentEm;
  final double? marginTopEm;
  final double? marginBottomEm;
  final String? textAlign;
  final double? fontSize;
  final String? imageAssetId;
  final String? imageAlt;
  final int? imageIntrinsicWidth;
  final int? imageIntrinsicHeight;

  const ReaderIrBlock({
    required this.kind,
    required this.plainStart,
    required this.plainLen,
    required this.text,
    required this.runs,
    required this.isHeading,
    required this.headingLevel,
    this.textIndentEm,
    this.marginTopEm,
    this.marginBottomEm,
    this.textAlign,
    this.fontSize,
    this.imageAssetId,
    this.imageAlt,
    this.imageIntrinsicWidth,
    this.imageIntrinsicHeight,
  });

  /// 默认首行缩进（em 单位）。
  static const double defaultFirstLineIndentEm = 2.0;

  // ==================== 块级计算（原 IrReaderIrBlock）====================

  /// 有效字号（块级覆盖）。
  static double effectiveFontSize(ReaderIrBlock block, double baseFontSize) {
    if (block.isHeading) {
      final level = block.headingLevel.clamp(1, 6);
      return _headingFontSizes[level - 1] * baseFontSize;
    }
    return block.fontSize ?? baseFontSize;
  }

  /// 有效行高（块级覆盖）。
  static double effectiveLineHeight(
    ReaderIrBlock block,
    double baseLineHeight,
  ) {
    if (block.headingLevel > 0) {
      return _headingLineHeights[block.headingLevel.clamp(1, 6) - 1];
    }
    return baseLineHeight;
  }

  /// 首行缩进 px（块级 + 用户配置），默认值 2em。
  static double resolveFirstLineIndentPx(
    ReaderIrBlock block,
    double baseFontSize,
    double fontSize,
    double? userIndentEm,
  ) {
    if (block.isHeading) return 0;
    if (block.textIndentEm == 0) return 0;
    final indentEm = userIndentEm ?? defaultFirstLineIndentEm;
    return indentEm * fontSize;
  }

  /// 块级 padding（默认 Text 块 0，Heading 块上边距 0.5em + 下边距 0.25em）。
  static ({double top, double bottom}) resolveBlockPadding(
    ReaderIrBlock block,
    double fontSize,
  ) {
    if (block.kind == ReaderIrBlockKind.image) {
      return (top: 4.0, bottom: 4.0);
    }
    if (block.isHeading) {
      final level = block.headingLevel.clamp(1, 6);
      final padding = _headingPaddings[level - 1];
      return (top: padding * fontSize, bottom: padding * fontSize * 0.5);
    }
    final marginTop = (block.marginTopEm ?? 0) * fontSize;
    final marginBottom = (block.marginBottomEm ?? 0) * fontSize;
    return (top: marginTop, bottom: marginBottom);
  }

  /// text-align 解析。
  static TextAlign resolveTextAlign(
    ReaderIrBlock block,
    TextAlign defaultAlign,
  ) {
    if (block.textAlign == null) return defaultAlign;
    switch (block.textAlign!) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return defaultAlign;
    }
  }
}

/// H1-H6 字号倍率。
const List<double> _headingFontSizes = [2.0, 1.5, 1.25, 1.1, 1.0, 1.0];

/// H1-H6 行高。
const List<double> _headingLineHeights = [1.3, 1.35, 1.4, 1.45, 1.5, 1.5];

/// H1-H6 上下边距（em）。
const List<double> _headingPaddings = [1.0, 0.8, 0.6, 0.4, 0.3, 0.3];

// ==================== 章 IR ====================

/// 章节 IR。
class ReaderChapterIr {
  final List<ReaderIrBlock> blocks;
  final String plainText;

  const ReaderChapterIr({required this.blocks, required this.plainText});

  /// 图片块数量。
  int get imageBlockCount =>
      blocks.where((b) => b.kind == ReaderIrBlockKind.image).length;
}

// ==================== 边界转换 ====================

/// 将 FRB `ReaderChapterIr` 转换为纯 Dart `ReaderChapterIr`。
///
/// 在 [`ChapterContentRepository`] 中收到 FRB 结果后立即调用一次，
/// 后续所有代码使用纯 Dart 类型。
ReaderChapterIr convertChapterIrFromFrb(dynamic frbIr) {
  return ReaderChapterIr(
    blocks: (frbIr.blocks as List<dynamic>)
        .map((b) => _convertBlockFromFrb(b))
        .toList(growable: false),
    plainText: frbIr.plainText as String,
  );
}

ReaderIrBlock _convertBlockFromFrb(dynamic frb) {
  return ReaderIrBlock(
    kind: _convertKindFromFrb(frb.kind),
    plainStart: frb.plainStart as int,
    plainLen: frb.plainLen as int,
    text: frb.text as String,
    runs: (frb.runs as List<dynamic>)
        .map((r) => _convertRunFromFrb(r))
        .toList(growable: false),
    isHeading: frb.isHeading as bool,
    headingLevel: frb.headingLevel as int,
    textIndentEm: (frb.textIndentEm as double?)?.toDouble(),
    marginTopEm: (frb.marginTopEm as double?)?.toDouble(),
    marginBottomEm: (frb.marginBottomEm as double?)?.toDouble(),
    textAlign: frb.textAlign as String?,
    fontSize: (frb.fontSize as double?)?.toDouble(),
    imageAssetId: frb.imageAssetId as String?,
    imageAlt: frb.imageAlt as String?,
    imageIntrinsicWidth: frb.imageIntrinsicWidth as int?,
    imageIntrinsicHeight: frb.imageIntrinsicHeight as int?,
  );
}

ReaderInlineRun _convertRunFromFrb(dynamic frb) {
  return ReaderInlineRun(
    text: frb.text as String,
    style: _convertStyleFromFrb(frb.style),
    url: frb.url as String?,
  );
}

ReaderInlineStyle _convertStyleFromFrb(dynamic frbStyle) {
  // FRB 枚举：ReaderInlineStyle 的 index (plain=0, bold=1, italic=2)
  final idx = frbStyle is int ? frbStyle : (frbStyle.index as int);
  switch (idx) {
    case 0:
      return ReaderInlineStyle.plain;
    case 1:
      return ReaderInlineStyle.bold;
    case 2:
      return ReaderInlineStyle.italic;
    default:
      return ReaderInlineStyle.plain;
  }
}

ReaderIrBlockKind _convertKindFromFrb(dynamic frbKind) {
  // FRB 枚举：ReaderIrBlockKind 的 index (text=0, image=1)
  final idx = frbKind is int ? frbKind : (frbKind.index as int);
  switch (idx) {
    case 0:
      return ReaderIrBlockKind.text;
    case 1:
      return ReaderIrBlockKind.image;
    default:
      return ReaderIrBlockKind.text;
  }
}
