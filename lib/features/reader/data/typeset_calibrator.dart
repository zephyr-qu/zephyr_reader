import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/layout_calibration_store.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

/// 无 Flutter 实测时的默认有效行宽比例（与 Rust `DEFAULT_EFFECTIVE_LINE_WIDTH_RATIO` 对齐）。
/// 主断行已用满页宽；此值主要用于诊断估算与缺省校准。
const kDefaultEffectiveLineWidthRatio = 1.0;

/// 统一测量输入：与阅读器渲染栈及 Rust [TypesetConfig] 对齐。
class TypesetMeasureParams {
  const TypesetMeasureParams({
    required this.width,
    required this.height,
    required this.pagePadding,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.fontFamily,
    required this.devicePixelRatio,
    this.contentVerticalPadding = 0,
    this.baselineAlign = true,
    this.firstLineIndentChars = 2,
  });

  final double width;
  final double height;
  final double pagePadding;
  final double contentVerticalPadding;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final String fontFamily;
  final double devicePixelRatio;
  final bool baselineAlign;
  final int firstLineIndentChars;

  double get availableContentWidthDp =>
      (width - 2 * pagePadding).clamp(1.0, width);
}

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

  Map<String, dynamic> toJson() => {
    'dpr': dpr,
    'cjkWidth': cjkWidth,
    'asciiWidth': asciiWidth,
    'digitWidth': digitWidth,
    'punctWidth': punctWidth,
    'latinExtWidth': latinExtWidth,
    'otherWidth': otherWidth,
    'effectiveLineWidthRatio': effectiveLineWidthRatio,
    'lineHeightDp': lineHeightDp,
  };

  factory CalibrationData.fromJson(Map<String, dynamic> json) {
    return CalibrationData(
      dpr: (json['dpr'] as num).toDouble(),
      cjkWidth: (json['cjkWidth'] as num).toDouble(),
      asciiWidth: (json['asciiWidth'] as num).toDouble(),
      digitWidth: (json['digitWidth'] as num).toDouble(),
      punctWidth: (json['punctWidth'] as num).toDouble(),
      latinExtWidth: (json['latinExtWidth'] as num).toDouble(),
      otherWidth: (json['otherWidth'] as num).toDouble(),
      effectiveLineWidthRatio:
          (json['effectiveLineWidthRatio'] as num?)?.toDouble() ??
          kDefaultEffectiveLineWidthRatio,
      lineHeightDp: (json['lineHeightDp'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 校准采样字符（每组 3-5 个代表性字符）
const _cjkSamples = '排版测量';
const _asciiSamples = 'Tex';
const _digitSamples = '012';
const _punctSamples = '，。！';
const _latinExtSamples = 'ñüé';
const _otherSamples = '◇Ω☕';

({TextStyle textStyle, StrutStyle strutStyle}) _measureStyles(
  TypesetMeasureParams params,
) {
  final config = ReaderRenderConfig(
    textColor: Colors.black,
    backgroundColor: Colors.white,
    fontSize: params.fontSize,
    lineHeight: params.lineHeight,
    fontFamily: params.fontFamily,
    letterSpacing: params.letterSpacing,
    paragraphSpacing: 16,
    pageMargin: params.pagePadding,
    showVocabularyMark: false,
    vocabularyWords: const {},
    baselineAlign: params.baselineAlign,
  );
  return (
    textStyle: config.buildTextStyle(),
    strutStyle: config.buildStrutStyle(),
  );
}

double _measureAvgCharWidth(
  String text,
  TextStyle textStyle,
  StrutStyle strutStyle,
) {
  if (text.isEmpty) return 0;
  final tp = TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout(maxWidth: double.infinity);
  return tp.width / text.length;
}

/// 用 TextPainter 测量 Flutter 有效行宽比例。
double measureEffectiveLineWidthRatio({
  required TextStyle textStyle,
  required StrutStyle strutStyle,
  required double availableWidthDp,
}) {
  if (availableWidthDp <= 1.0) return kDefaultEffectiveLineWidthRatio;

  final singleTp = TextPainter(
    text: TextSpan(text: '中', style: textStyle),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout();
  final singleWidth = singleTp.width;
  if (singleWidth <= 0) return kDefaultEffectiveLineWidthRatio;

  final repeatCount = ((availableWidthDp / singleWidth).ceil() * 3).clamp(
    1,
    500,
  );
  final testStr = '中' * repeatCount;

  final tp = TextPainter(
    text: TextSpan(text: testStr, style: textStyle),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout(maxWidth: availableWidthDp);

  final metrics = tp.computeLineMetrics();
  if (metrics.isEmpty) return kDefaultEffectiveLineWidthRatio;

  final firstLineWidth = metrics.first.width;
  final charsPerLine = (firstLineWidth / singleWidth).round().clamp(
    1,
    repeatCount,
  );
  final effectiveWidth = charsPerLine * singleWidth;
  final ratio = (effectiveWidth / availableWidthDp).clamp(0.85, 1.0);

  Logging.info(
    '[LineWidthCalib] single=${singleWidth.toStringAsFixed(1)}dp'
    ' charsPerLine=$charsPerLine'
    ' effective=${effectiveWidth.toStringAsFixed(1)}dp'
    ' available=${availableWidthDp.toStringAsFixed(1)}dp'
    ' ratio=${ratio.toStringAsFixed(3)}',
  );
  return ratio;
}

/// 实测单行高度（逻辑 dp），与分页 [StrutStyle] 一致。
double measureLineHeightDp({
  required TextStyle textStyle,
  required StrutStyle strutStyle,
}) {
  final tp = TextPainter(
    text: TextSpan(text: '中', style: textStyle),
    textDirection: TextDirection.ltr,
    strutStyle: strutStyle,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  )..layout(maxWidth: double.infinity);
  final metrics = tp.computeLineMetrics();
  if (metrics.isEmpty) return textStyle.fontSize! * (textStyle.height ?? 1.0);
  return metrics.first.height;
}

/// 统一排版指纹测量（字宽 + 行宽比 + 行高），使用与渲染相同的 TextPainter 栈。
CalibrationData measureLayoutFingerprint(TypesetMeasureParams params) {
  final styles = _measureStyles(params);
  final cjkWidth = _measureAvgCharWidth(
    _cjkSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final asciiWidth = _measureAvgCharWidth(
    _asciiSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final digitWidth = _measureAvgCharWidth(
    _digitSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final punctWidth = _measureAvgCharWidth(
    _punctSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final latinExtWidth = _measureAvgCharWidth(
    _latinExtSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final otherWidth = _measureAvgCharWidth(
    _otherSamples,
    styles.textStyle,
    styles.strutStyle,
  );
  final lineWidthRatio = measureEffectiveLineWidthRatio(
    textStyle: styles.textStyle,
    strutStyle: styles.strutStyle,
    availableWidthDp: params.availableContentWidthDp,
  );
  final lineHeightDp = measureLineHeightDp(
    textStyle: styles.textStyle,
    strutStyle: styles.strutStyle,
  );

  Logging.info(
    '[LayoutCalib] measure complete cjk=${cjkWidth.toStringAsFixed(2)}dp'
    ' lineH=${lineHeightDp.toStringAsFixed(2)}dp'
    ' ratio=${lineWidthRatio.toStringAsFixed(3)}'
    ' font=${params.fontFamily} size=${params.fontSize}',
  );

  return CalibrationData(
    dpr: params.devicePixelRatio,
    cjkWidth: cjkWidth,
    asciiWidth: asciiWidth,
    digitWidth: digitWidth,
    punctWidth: punctWidth,
    latinExtWidth: latinExtWidth,
    otherWidth: otherWidth,
    effectiveLineWidthRatio: lineWidthRatio,
    lineHeightDp: lineHeightDp,
  );
}

/// 读本地缓存；未命中则 [measureLayoutFingerprint] 并写入缓存。
Future<CalibrationData?> resolveLayoutCalibration({
  required TypesetMeasureParams params,
  required PreferencesService prefs,
  int maxRetries = 2,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  final key = LayoutCalibrationStore.cacheKey(params);
  final cached = LayoutCalibrationStore.load(prefs, key);
  if (cached != null && isCalibrationPlausible(cached, params.fontSize)) {
    Logging.info('[LayoutCalib] cache hit key=$key');
    return cached;
  }

  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final measured = measureLayoutFingerprint(params);
      final ratio = measured.cjkWidth / params.fontSize;
      if (ratio < 0.5 || ratio > 1.5) {
        if (attempt < maxRetries) {
          Logging.info(
            '[LayoutCalib] CJK ratio=$ratio out of range, retry $attempt',
          );
          await Future<void>.delayed(retryDelay);
          continue;
        }
        Logging.info('[LayoutCalib] CJK ratio=$ratio, using defaults');
        return defaultCalibrationData(
          fontSize: params.fontSize,
          lineHeight: params.lineHeight,
          devicePixelRatio: params.devicePixelRatio,
        );
      }
      await LayoutCalibrationStore.save(prefs, key, measured);
      return measured;
    } catch (e) {
      if (attempt < maxRetries) {
        Logging.error('[LayoutCalib] measure error ($attempt): $e');
        await Future<void>.delayed(retryDelay);
        continue;
      }
      Logging.error('[LayoutCalib] measure failed: $e');
      return null;
    }
  }
  return null;
}

/// Unicode 分类，与 Rust `CharWidthTable::char_width` 区间对齐。
enum _CharCategory { cjk, digit, ascii, punct, latinExt, other }

_CharCategory _charCategory(String ch) {
  if (ch.isEmpty) return _CharCategory.other;
  final code = ch.codeUnitAt(0);
  if ((code >= 0x4E00 && code <= 0x9FFF) ||
      (code >= 0x3400 && code <= 0x4DBF)) {
    return _CharCategory.cjk;
  }
  if (code >= 0x30 && code <= 0x39) return _CharCategory.digit;
  if (code >= 0x20 && code <= 0x7F) return _CharCategory.ascii;
  if ((code >= 0x3000 && code <= 0x303F) ||
      (code >= 0xFF00 && code <= 0xFFEF)) {
    return _CharCategory.punct;
  }
  if (code >= 0xC0 && code <= 0x24F) return _CharCategory.latinExt;
  return _CharCategory.other;
}

String _sampleCharsFromText(
  String text,
  _CharCategory category, {
  int maxSamples = 24,
}) {
  final seen = <String>{};
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    if (_charCategory(ch) != category) continue;
    if (seen.add(ch)) buffer.write(ch);
    if (seen.length >= maxSamples) break;
  }
  return buffer.toString();
}

double? _avgWidthForCategory(
  String samples,
  TextStyle textStyle,
  StrutStyle strutStyle,
) {
  if (samples.isEmpty) return null;
  return _measureAvgCharWidth(samples, textStyle, strutStyle);
}

/// 从首屏实际文本采样各 Unicode 区间字宽（P4-4 / ADR-013）。
CalibrationData? calibrateFromPageText({
  required String pageText,
  required double fontSize,
  required double devicePixelRatio,
  required String fontFamily,
  CalibrationData? baseline,
  double lineHeight = 1.5,
  double letterSpacing = 0,
  double width = 400,
  double height = 600,
  double padding = 16,
  int maxSamplesPerCategory = 24,
}) {
  if (pageText.trim().isEmpty) return null;

  final params = TypesetMeasureParams(
    width: width,
    height: height,
    pagePadding: padding,
    fontSize: fontSize,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
    fontFamily: fontFamily,
    devicePixelRatio: devicePixelRatio,
    contentVerticalPadding: ReaderRenderConfig.pageContentVerticalPadding,
  );
  final styles = _measureStyles(params);

  final cjkSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.cjk,
    maxSamples: maxSamplesPerCategory,
  );
  final asciiSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.ascii,
    maxSamples: maxSamplesPerCategory,
  );
  final digitSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.digit,
    maxSamples: maxSamplesPerCategory,
  );
  final punctSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.punct,
    maxSamples: maxSamplesPerCategory,
  );
  final latinExtSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.latinExt,
    maxSamples: maxSamplesPerCategory,
  );
  final otherSamples = _sampleCharsFromText(
    pageText,
    _CharCategory.other,
    maxSamples: maxSamplesPerCategory,
  );

  final hasAnySamples =
      cjkSamples.isNotEmpty ||
      asciiSamples.isNotEmpty ||
      digitSamples.isNotEmpty ||
      punctSamples.isNotEmpty ||
      latinExtSamples.isNotEmpty ||
      otherSamples.isNotEmpty;
  if (!hasAnySamples) return baseline;

  final fallback = baseline ?? measureLayoutFingerprint(params);

  return CalibrationData(
    dpr: devicePixelRatio,
    cjkWidth:
        _avgWidthForCategory(cjkSamples, styles.textStyle, styles.strutStyle) ??
        fallback.cjkWidth,
    asciiWidth:
        _avgWidthForCategory(
          asciiSamples,
          styles.textStyle,
          styles.strutStyle,
        ) ??
        fallback.asciiWidth,
    digitWidth:
        _avgWidthForCategory(
          digitSamples,
          styles.textStyle,
          styles.strutStyle,
        ) ??
        fallback.digitWidth,
    punctWidth:
        _avgWidthForCategory(
          punctSamples,
          styles.textStyle,
          styles.strutStyle,
        ) ??
        fallback.punctWidth,
    latinExtWidth:
        _avgWidthForCategory(
          latinExtSamples,
          styles.textStyle,
          styles.strutStyle,
        ) ??
        fallback.latinExtWidth,
    otherWidth:
        _avgWidthForCategory(
          otherSamples,
          styles.textStyle,
          styles.strutStyle,
        ) ??
        fallback.otherWidth,
    effectiveLineWidthRatio: fallback.effectiveLineWidthRatio,
    lineHeightDp: fallback.lineHeightDp,
  );
}

/// 判断两次校准是否存在显著漂移（相对误差超过 [threshold]）。
bool calibrationDriftExceeds(
  CalibrationData baseline,
  CalibrationData refined, {
  double threshold = 0.03,
}) {
  bool drift(double a, double b) {
    if (a <= 0) return false;
    return (a - b).abs() / a > threshold;
  }

  return drift(baseline.cjkWidth, refined.cjkWidth) ||
      drift(baseline.asciiWidth, refined.asciiWidth) ||
      drift(baseline.digitWidth, refined.digitWidth) ||
      drift(baseline.punctWidth, refined.punctWidth) ||
      drift(baseline.latinExtWidth, refined.latinExtWidth) ||
      drift(baseline.otherWidth, refined.otherWidth) ||
      drift(
        baseline.effectiveLineWidthRatio,
        refined.effectiveLineWidthRatio,
      ) ||
      drift(baseline.lineHeightDp, refined.lineHeightDp);
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

bool isCalibrationPlausible(CalibrationData data, double fontSize) {
  if (fontSize <= 0) return false;
  final ratio = data.cjkWidth / fontSize;
  return ratio >= 0.5 && ratio <= 1.5;
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
  // 实测行高优先（strut 常为 32，而 fontSize×倍数可能只有 27）。
  final row = (measuredLineHeightDp != null && measuredLineHeightDp > 0)
      ? measuredLineHeightDp
      : fontSize * lineHeight;
  // 一次做对：Rust 与 Flutter 双引擎无法像素级一致。
  // 留满 1 行安全高，保证永不裁切（接受每页约 1 行底空）。
  // 真机残余漂移曾到 ~8–20dp；半行 buffer 仍会出现 paragraphSpacing overflow。
  return (
    contentVerticalPadding: ReaderRenderConfig.pageContentVerticalPadding,
    pageHeightLineBuffer: row.clamp(16.0, 48.0),
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

/// 从 [PaginationCoordinator] 当前布局参数构建测量输入。
TypesetMeasureParams typesetMeasureParamsFromLayout({
  required double pageWidth,
  required double pageHeight,
  required double pagePadding,
  required double fontSize,
  required double lineHeight,
  required double letterSpacing,
  required String fontFamily,
  required double devicePixelRatio,
  required bool baselineAlign,
  required bool firstLineIndent,
}) {
  final layoutInsets = paginatedTypesetLayoutInsets(
    fontSize: fontSize,
    lineHeight: lineHeight,
  );
  return TypesetMeasureParams(
    width: pageWidth,
    height: pageHeight,
    pagePadding: pagePadding,
    contentVerticalPadding: layoutInsets.contentVerticalPadding,
    fontSize: fontSize,
    lineHeight: lineHeight,
    letterSpacing: letterSpacing,
    fontFamily: fontFamily,
    devicePixelRatio: devicePixelRatio,
    baselineAlign: baselineAlign,
    firstLineIndentChars: firstLineIndent ? 2 : 0,
  );
}
