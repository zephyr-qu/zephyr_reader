library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
CalibrationData calibrateCharacterWidths({
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
  int maxRetries = 3,
  Duration retryDelay = const Duration(milliseconds: 100),
}) async {
  for (int attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      final result = calibrateCharacterWidths(
        fontSize: fontSize,
        devicePixelRatio: devicePixelRatio,
        fontFamily: fontFamily,
      );

      // 防御性校验：CJK 宽度明显异常 => 字体未就绪
      final expectedCjk = fontSize * devicePixelRatio;
      final ratio = result.cjkWidth / expectedCjk;
      if (ratio < 0.5 || ratio > 1.5) {
        if (attempt < maxRetries) {
          debugPrint(
            'calibrateSafely: CJK width ratio=$ratio (expected ~1.0), '
            'retrying ($attempt/$maxRetries)',
          );
          await Future<void>.delayed(retryDelay);
          continue;
        }
        debugPrint(
          'calibrateSafely: CJK width ratio=$ratio out of range, '
          'returning null after $maxRetries retries',
        );
        return null;
      }

      return result;
    } catch (e) {
      if (attempt < maxRetries) {
        debugPrint('calibrateSafely: error ($attempt/$maxRetries): $e');
        await Future<void>.delayed(retryDelay);
        continue;
      }
      debugPrint(
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
