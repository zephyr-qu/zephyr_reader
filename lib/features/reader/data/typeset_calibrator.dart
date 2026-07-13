import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

/// 排版测量 / 校准（ADR-013）。
///
/// ADR-016：Flutter→Rust 校准写回环已移除。Flutter 精确分页不依赖校准。
/// 测量工具可保留作诊断；勿再扩展写回 session 的路径。
///
/// 无 Flutter 实测时的默认有效行宽比例（与 Rust `DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO` 对齐）。
/// 主断行已用满页宽；此值主要用于诊断估算与缺省校准。
const kDefaultEffectiveLineWidthRatio = 1.0;

/// Flutter 侧排版指纹（传递到 Rust 前转换为 FRB [TypesetCalibration]）。
class CalibrationData {
  final double dpr;
  final double cjkWidth;
  final double asciiWidth;
  final double digitWidth;
  final double punctWidth;
  final double latinExtWidth;
  final double otherWidth;

  /// 有效行宽 / 可用行宽（逻辑 dp 维度，无量纲）。
  final double effectiveLineWidthRatio;

  /// TextPainter + StrutStyle 实测单行高度（逻辑 dp）。
  final double lineHeightDp;

  const CalibrationData({
    required this.dpr,
    required this.cjkWidth,
    required this.asciiWidth,
    required this.digitWidth,
    required this.punctWidth,
    required this.latinExtWidth,
    required this.otherWidth,
    required this.effectiveLineWidthRatio,
    required this.lineHeightDp,
  });
}

CalibrationData defaultCalibrationData({
  required double fontSize,
  required double devicePixelRatio,
  double lineHeight = 1.5,
}) {
  return CalibrationData(
    dpr: devicePixelRatio,
    cjkWidth: fontSize,
    asciiWidth: fontSize * 0.6,
    digitWidth: fontSize * 0.6,
    punctWidth: fontSize,
    latinExtWidth: fontSize * 0.7,
    otherWidth: fontSize * 0.8,
    effectiveLineWidthRatio: kDefaultEffectiveLineWidthRatio,
    lineHeightDp: fontSize * lineHeight,
  );
}

double estimateRustMaxLineWidthPx({
  required int pageWidthPx,
  required int fontSizePx,
  double effectiveLineWidthRatio = kDefaultEffectiveLineWidthRatio,
  int firstLineIndentChars = 2,
  bool subtractFirstLineIndent = false,
}) {
  // 与 Rust 主断行对齐：使用满页宽。ratio 参数保留以兼容旧测试调用，但默认 1.0。
  final effectiveWidth = pageWidthPx * effectiveLineWidthRatio;
  if (!subtractFirstLineIndent) {
    return effectiveWidth.clamp(fontSizePx.toDouble(), effectiveWidth);
  }
  final indentPx = fontSizePx * firstLineIndentChars;
  return (effectiveWidth - indentPx).clamp(
    fontSizePx.toDouble(),
    effectiveWidth,
  );
}

double estimateRustCharsPerLine({
  required double cjkWidthPx,
  required int pageWidthPx,
  required int fontSizePx,
  double effectiveLineWidthRatio = kDefaultEffectiveLineWidthRatio,
  int firstLineIndentChars = 2,
  bool subtractFirstLineIndent = false,
}) {
  if (cjkWidthPx <= 0) return 0;
  // 与 Rust BlockLayoutMetrics 对齐：断行使用满页宽，不再乘 ratio。
  final maxLinePx = estimateRustMaxLineWidthPx(
    pageWidthPx: pageWidthPx,
    fontSizePx: fontSizePx,
    effectiveLineWidthRatio: 1.0,
    firstLineIndentChars: firstLineIndentChars,
    subtractFirstLineIndent: subtractFirstLineIndent,
  );
  return maxLinePx / cjkWidthPx;
}

/// 与 Rust [CharWidthTable::char_width] 区间对齐的单字符宽度（物理 px）。
double rustCharWidthPx({
  required int rune,
  required double cjkWidthPx,
  double? asciiWidthPx,
  double? digitWidthPx,
  double? punctWidthPx,
  double? latinExtWidthPx,
  double? otherWidthPx,
}) {
  final ascii = asciiWidthPx ?? cjkWidthPx * 0.6;
  final digit = digitWidthPx ?? ascii;
  final punct = punctWidthPx ?? cjkWidthPx;
  final latinExt = latinExtWidthPx ?? cjkWidthPx * 0.7;
  final other = otherWidthPx ?? cjkWidthPx * 0.8;

  if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF)) {
    return cjkWidthPx;
  }
  if (rune >= 0x0030 && rune <= 0x0039) return digit;
  if (rune >= 0x0020 && rune <= 0x007F) return ascii;
  if ((rune >= 0x3000 && rune <= 0x303F) ||
      (rune >= 0xFF00 && rune <= 0xFFEF)) {
    return punct;
  }
  if (rune >= 0x00C0 && rune <= 0x024F) return latinExt;
  return other;
}

/// 变宽贪心行数估算（对齐 Rust CharWidthTable + 满页宽断行；不含 auto_space/标点挤压）。
int estimateRustLinesForText({
  required String text,
  required bool applyFirstLineIndent,
  required double cjkWidthPx,
  required int pageWidthPx,
  required int fontSizePx,
  double effectiveLineWidthRatio = kDefaultEffectiveLineWidthRatio,
  int firstLineIndentChars = 2,
  double? asciiWidthPx,
  double? digitWidthPx,
  double? punctWidthPx,
  double? latinExtWidthPx,
  double? otherWidthPx,
}) {
  if (text.isEmpty) return 0;

  // Packing 与 Rust 一致用满页宽；ratio 仅保留 API 兼容（诊断不再用其收窄）。
  assert(effectiveLineWidthRatio > 0);

  final fullLinePx = estimateRustMaxLineWidthPx(
    pageWidthPx: pageWidthPx,
    fontSizePx: fontSizePx,
    effectiveLineWidthRatio: 1.0,
    firstLineIndentChars: firstLineIndentChars,
  );
  final firstLinePx = applyFirstLineIndent
      ? estimateRustMaxLineWidthPx(
          pageWidthPx: pageWidthPx,
          fontSizePx: fontSizePx,
          effectiveLineWidthRatio: 1.0,
          firstLineIndentChars: firstLineIndentChars,
          subtractFirstLineIndent: true,
        )
      : fullLinePx;

  var lines = 1;
  var current = 0.0;
  var isFirstLine = true;

  for (final rune in text.runes) {
    if (rune == 0x0A) {
      lines++;
      current = 0.0;
      isFirstLine = false;
      continue;
    }
    final w = rustCharWidthPx(
      rune: rune,
      cjkWidthPx: cjkWidthPx,
      asciiWidthPx: asciiWidthPx,
      digitWidthPx: digitWidthPx,
      punctWidthPx: punctWidthPx,
      latinExtWidthPx: latinExtWidthPx,
      otherWidthPx: otherWidthPx,
    );
    final limit = isFirstLine ? firstLinePx : fullLinePx;
    if (current > 0 && current + w > limit) {
      lines++;
      current = w;
      isFirstLine = false;
    } else {
      current += w;
    }
  }

  return lines;
}

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

TypesetCalibration calibrationToRust(CalibrationData data) {
  final dpr = data.dpr;
  return TypesetCalibration(
    dpr: dpr,
    cjkWidth: data.cjkWidth * dpr,
    asciiWidth: data.asciiWidth * dpr,
    digitWidth: data.digitWidth * dpr,
    punctWidth: data.punctWidth * dpr,
    otherWidth: data.otherWidth * dpr,
    latinExtWidth: data.latinExtWidth * dpr,
    effectiveLineWidthRatio: data.effectiveLineWidthRatio,
    measuredLineHeightPx: data.lineHeightDp * dpr,
  );
}

({double contentVerticalPadding, double pageHeightLineBuffer})
paginatedTypesetLayoutInsets({
  required double fontSize,
  required double lineHeight,
  double paragraphSpacing = 16,
  double? measuredLineHeightDp,
}) {
  // 实测行高优先（与正文多行平均对齐）。
  final row = (measuredLineHeightDp != null && measuredLineHeightDp > 0)
      ? measuredLineHeightDp
      : fontSize * lineHeight;
  // ICU 按块断行后残余漂移通常 < 0.5 行；满行 buffer 会造成系统性底空 ~1 行。
  return (
    contentVerticalPadding: ReaderRenderConfig.pageContentVerticalPadding,
    pageHeightLineBuffer: (row * 0.5).clamp(8.0, 24.0),
  );
}

TypesetConfig buildTypesetConfig({
  required double width,
  required double height,
  required double fontSize,
  required double lineHeight,
  double padding = 16,
  double contentVerticalPadding = 0,
  double pageHeightLineBuffer = 0,
  double devicePixelRatio = 1.0,
  double autoSpaceRatio = 0.25,
  int firstLineIndent = 2,
  CalibrationData? calibration,
  String fontFamily = 'Noto Sans SC',
  double letterSpacing = 0,
  double paragraphSpacing = 16,
  bool punctuationSqueeze = true,
  LanguageType language = LanguageType.auto,
}) {
  final effectiveCalibration =
      calibration ??
      defaultCalibrationData(
        fontSize: fontSize,
        devicePixelRatio: devicePixelRatio,
        lineHeight: lineHeight,
      );
  final rustCalibration = calibrationToRust(effectiveCalibration);
  final calibSource = calibration != null ? 'measured' : 'default';

  final contentHeight =
      (height - 2 * contentVerticalPadding - pageHeightLineBuffer).clamp(
        100.0,
        height,
      );
  final pageHeightPx = (contentHeight * devicePixelRatio).round();
  final pageWidthPx = ((width - 2 * padding) * devicePixelRatio).round();
  final lineHeightPx = effectiveCalibration.lineHeightDp * devicePixelRatio;
  final estLines = pageHeightPx > 0 && lineHeightPx > 0
      ? pageHeightPx / lineHeightPx
      : 0;
  Logging.info(
    '[PageEstimate] buildTypesetConfig height_dp=${height.toStringAsFixed(1)}'
    ' contentVPad=2*$contentVerticalPadding=${(2 * contentVerticalPadding).toStringAsFixed(1)}'
    ' lineBuf=${pageHeightLineBuffer.toStringAsFixed(1)}'
    ' contentH_dp=${contentHeight.toStringAsFixed(1)}'
    ' dpr=${devicePixelRatio.toStringAsFixed(1)}'
    ' pageHeight=$pageHeightPx px'
    ' pageWidth=$pageWidthPx px'
    ' fontSize=${fontSize.toStringAsFixed(1)} dp'
    ' lineH=${lineHeightPx.toStringAsFixed(1)}px'
    ' ratio=${effectiveCalibration.effectiveLineWidthRatio.toStringAsFixed(3)}'
    ' estLinesPerPage=${estLines.toStringAsFixed(1)}',
  );
  Logging.info(
    '[PageEstimate] calib($calibSource) cjk=${rustCalibration.cjkWidth.toStringAsFixed(1)}'
    ' ascii=${rustCalibration.asciiWidth.toStringAsFixed(1)}'
    ' punct=${rustCalibration.punctWidth.toStringAsFixed(1)}'
    ' dpr=${rustCalibration.dpr.toStringAsFixed(1)}'
    ' fontPx=${(fontSize * devicePixelRatio).round()}',
  );

  return TypesetConfig(
    pageWidth: pageWidthPx,
    pageHeight: pageHeightPx,
    fontSize: (fontSize * devicePixelRatio).round(),
    lineSpacing: lineHeight,
    letterSpacing: letterSpacing * devicePixelRatio,
    paragraphSpacing: (paragraphSpacing / fontSize).clamp(0.0, 10.0),
    firstLineIndent: firstLineIndent,
    autoSpaceRatio: autoSpaceRatio,
    language: language,
    punctuationSqueeze: punctuationSqueeze,
    fontFamily: fontFamily,
    calibration: rustCalibration,
  );
}
