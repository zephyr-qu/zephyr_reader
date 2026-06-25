import 'dart:ui' as ui;

import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// Flutter 侧字符宽度校准数据
///
/// 每组取 3-5 个代表字符，用 TextPainter 测量真实像素宽度后取平均。
/// 注意：此类型在传递到 Rust 前会被转换为 FRB 生成的 `TypesetCalibration`。
class CalibrationData {
  final double dpr;
  final double cjkWidth;
  final double asciiWidth;
  final double digitWidth;
  final double punctWidth;
  final double otherWidth;

  const CalibrationData({
    required this.dpr,
    required this.cjkWidth,
    required this.asciiWidth,
    required this.digitWidth,
    required this.punctWidth,
    required this.otherWidth,
  });
}

/// 校准采样字符（每组 3-5 个代表性字符）
const _cjkSamples = '排版测量';
const _asciiSamples = 'Tex';
const _digitSamples = '012';
const _punctSamples = '，。！';
const _otherSamples = 'ñüé';

/// 执行字符宽度校准
///
/// 在字体已加载的前提下，测量 5 组 Unicode 区间的真实像素宽度。
/// 总耗时目标 < 2ms（每组测量仅 3-5 个字符）。
CalibrationData _calibrateCharacterWidths({
  required double fontSize,
  required double devicePixelRatio,
  String fontFamily = 'Noto Sans SC',
}) {
  assert(fontSize > 0, 'fontSize must be positive');
  assert(devicePixelRatio > 0, 'devicePixelRatio must be positive');

  final cjkWidth = _measureWidth(_cjkSamples, fontSize, fontFamily);
  final asciiWidth = _measureWidth(_asciiSamples, fontSize, fontFamily);
  final digitWidth = _measureWidth(_digitSamples, fontSize, fontFamily);
  final punctWidth = _measureWidth(_punctSamples, fontSize, fontFamily);
  final otherWidth = _measureWidth(_otherSamples, fontSize, fontFamily);

  return CalibrationData(
    dpr: devicePixelRatio,
    cjkWidth: cjkWidth,
    asciiWidth: asciiWidth,
    digitWidth: digitWidth,
    punctWidth: punctWidth,
    otherWidth: otherWidth,
  );
}

/// 安全执行的校准（带字体就绪检测 + 重试）
///
/// 返回 `null` 表示字体未就绪（调用方应使用保守默认值）。
/// [maxRetries] 最大重试次数，[retryDelay] 每次重试间隔。
Future<CalibrationData?> calibrateSafely({
  required double fontSize,
  required double devicePixelRatio,
  String fontFamily = 'Noto Sans SC',
  int maxRetries = 2,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final result = _calibrateCharacterWidths(
        fontSize: fontSize,
        devicePixelRatio: devicePixelRatio,
        fontFamily: fontFamily,
      );

      // 防御性校验：CJK 宽度明显异常 => 字体未就绪
      // cjkWidth 是 Flutter 逻辑像素（maxIntrinsicWidth / char count），
      // fontSize 也是逻辑像素 — CJK 字符宽度 ≈ fontSize，比例应 ~1.0
      final ratio = result.cjkWidth / fontSize;
      if (ratio < 0.5 || ratio > 1.5) {
        if (attempt < maxRetries) {
          Logging.info(
            'calibrateSafely: CJK width ratio=$ratio (expected ~1.0), '
            'retrying ($attempt/$maxRetries)',
          );
          await Future<void>.delayed(retryDelay);
          continue;
        }
        Logging.info(
          'calibrateSafely: CJK width ratio=$ratio out of range, '
          'returning null after $maxRetries retries',
        );
        return null;
      }

      return result;
    } catch (e) {
      if (attempt < maxRetries) {
        Logging.error('calibrateSafely: error ($attempt/$maxRetries): $e');
        await Future<void>.delayed(retryDelay);
        continue;
      }
      Logging.error(
        'calibrateSafely: returning null after $maxRetries retries: $e',
      );
      return null;
    }
  }
  return null;
}

double _measureWidth(String text, double fontSize, String fontFamily) {
  final paragraph =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            textDirection: ui.TextDirection.ltr,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        )
        ..pushStyle(ui.TextStyle(fontSize: fontSize, fontFamily: fontFamily))
        ..addText(text);

  final constraints = const ui.ParagraphConstraints(width: 10000);
  final paragraphObj = paragraph.build()..layout(constraints);
  return paragraphObj.maxIntrinsicWidth / text.length;
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
  double fontSize,
  String fontFamily,
) {
  if (samples.isEmpty) return null;
  return _measureWidth(samples, fontSize, fontFamily);
}

/// 从首屏实际文本采样各 Unicode 区间字宽（P4-4 / ADR-013）。
///
/// 某类字符在 [pageText] 中不存在时，回退到 [baseline] 对应值。
CalibrationData? calibrateFromPageText({
  required String pageText,
  required double fontSize,
  required double devicePixelRatio,
  required String fontFamily,
  CalibrationData? baseline,
  int maxSamplesPerCategory = 24,
}) {
  if (pageText.trim().isEmpty) return null;

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

  final hasAnySamples = cjkSamples.isNotEmpty ||
      asciiSamples.isNotEmpty ||
      digitSamples.isNotEmpty ||
      punctSamples.isNotEmpty ||
      latinExtSamples.isNotEmpty ||
      otherSamples.isNotEmpty;
  if (!hasAnySamples) return baseline;

  final fallback = baseline ??
      _calibrateCharacterWidths(
        fontSize: fontSize,
        devicePixelRatio: devicePixelRatio,
        fontFamily: fontFamily,
      );

  final latinOrOther = latinExtSamples.isNotEmpty
      ? latinExtSamples
      : otherSamples;

  return CalibrationData(
    dpr: devicePixelRatio,
    cjkWidth: _avgWidthForCategory(cjkSamples, fontSize, fontFamily) ??
        fallback.cjkWidth,
    asciiWidth: _avgWidthForCategory(asciiSamples, fontSize, fontFamily) ??
        fallback.asciiWidth,
    digitWidth: _avgWidthForCategory(digitSamples, fontSize, fontFamily) ??
        fallback.digitWidth,
    punctWidth: _avgWidthForCategory(punctSamples, fontSize, fontFamily) ??
        fallback.punctWidth,
    otherWidth: _avgWidthForCategory(latinOrOther, fontSize, fontFamily) ??
        fallback.otherWidth,
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
      drift(baseline.otherWidth, refined.otherWidth);
}

/// CJK 宽度与 [fontSize] 比例是否在合理区间（与 calibrateSafely 一致）。
bool isCalibrationPlausible(CalibrationData data, double fontSize) {
  if (fontSize <= 0) return false;
  final ratio = data.cjkWidth / fontSize;
  return ratio >= 0.5 && ratio <= 1.5;
}

/// 将 [CalibrationData] 转为 Rust FRB 类型。
TypesetCalibration calibrationToRust(CalibrationData data) {
  return TypesetCalibration(
    dpr: data.dpr,
    cjkWidth: data.cjkWidth,
    asciiWidth: data.asciiWidth,
    digitWidth: data.digitWidth,
    punctWidth: data.punctWidth,
    otherWidth: data.otherWidth,
    latinExtWidth: data.otherWidth,
  );
}

// ===== Typeset config builder =====

/// 将 Flutter UI 参数转换为 Rust TypesetConfig
///
/// [width] / [height]: 页面可用逻辑像素（dp），来自 MediaQuery.size - padding
/// [fontSize]: 字体大小（逻辑像素 dp）
/// [lineHeight]: 行高倍数（如 1.5）
/// [padding]: 四边距（逻辑像素 dp）
/// [devicePixelRatio]: 设备像素比
/// [calibration]: 字符宽度校准数据（可选）
/// [fontFamily]: 当前字体系列名
/// [letterSpacing]: 字间距（逻辑像素 dp）
/// [paragraphSpacing]: 段落间距（逻辑像素 dp）
/// [language]: 语言类型
TypesetConfig buildTypesetConfig({
  required double width,
  required double height,
  required double fontSize,
  required double lineHeight,
  double padding = 16,
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
  final rustCalibration = calibration != null
      ? calibrationToRust(calibration)
      : null;

  return TypesetConfig(
    pageWidth: ((width - 2 * padding) * devicePixelRatio).round(),
    pageHeight: (height * devicePixelRatio).round(),
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
