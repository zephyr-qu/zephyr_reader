/// 排版配置构建器
///
/// 统一将 Flutter UI 参数（逻辑像素 dp）转换为 Rust TypesetConfig（物理像素 px）。
/// 所有排版相关的参数转换必须经过此模块，禁止在 ViewModel 中直接拼凑 Config。
library;

import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

/// 将 Flutter UI 参数转换为 Rust TypesetConfig
///
/// [width] / [height]: 页面可用逻辑像素（dp），来自 MediaQuery.size - padding
/// [fontSize]: 字体大小（逻辑像素 dp）
/// [lineHeight]: 行高倍数（如 1.5）
/// [padding]: 四边距（逻辑像素 dp）
/// [devicePixelRatio]: 设备像素比，来自 MediaQuery.devicePixelRatio 或 ViewConfiguration
/// [calibration]: 字符宽度校准数据（可选），来自 calibrateCharacterWidths()
/// [fontFamily]: 当前字体系列名
TypesetConfig buildTypesetConfig({
  required double width,
  required double height,
  required double fontSize,
  required double lineHeight,
  double padding = 16,
  double devicePixelRatio = 1.0,
  int firstLineIndent = 2,
  CalibrationData? calibration,
  String fontFamily = 'Noto Sans SC',
}) {
  final scale = devicePixelRatio;
  final rustCalibration = calibration != null
      ? TypesetCalibration(
          dpr: calibration.dpr,
          cjkWidth: calibration.cjkWidth,
          asciiWidth: calibration.asciiWidth,
          digitWidth: calibration.digitWidth,
          punctWidth: calibration.punctWidth,
          otherWidth: calibration.otherWidth,
          latinExtWidth: 0.0,
        )
      : null;

  return TypesetConfig(
    pageWidth: (width * scale).round(),
    pageHeight: (height * scale).round(),
    fontSize: (fontSize * scale).round(),
    lineSpacing: lineHeight,
    letterSpacing: 0,
    paragraphSpacing: lineHeight,
    firstLineIndent: firstLineIndent,
    language: LanguageType.mixed,
    enableHyphenation: false,
    fontFamily: fontFamily,
    calibration: rustCalibration,
  );
}

/// 从 MediaQuery 中提取 devicePixelRatio 并构建配置
TypesetConfig buildTypesetConfigFromMediaQuery({
  required dynamic mediaQuery,
  required double width,
  required double height,
  required double fontSize,
  required double lineHeight,
  double padding = 16,
  int firstLineIndent = 2,
  CalibrationData? calibration,
  String fontFamily = 'Noto Sans SC',
}) {
  final dpr = mediaQuery.devicePixelRatio as double;
  return buildTypesetConfig(
    width: width,
    height: height,
    fontSize: fontSize,
    lineHeight: lineHeight,
    padding: padding,
    devicePixelRatio: dpr,
    firstLineIndent: firstLineIndent,
    calibration: calibration,
    fontFamily: fontFamily,
  );
}
