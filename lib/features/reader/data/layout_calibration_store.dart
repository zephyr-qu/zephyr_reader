import 'dart:convert';

import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';

/// 本地持久化 Flutter 统一排版测量结果（按设备 + 排版参数指纹缓存）。
abstract final class LayoutCalibrationStore {
  static const _keyPrefix = 'layout_calib_v1_';

  /// 由 [TypesetMeasureParams] 生成稳定缓存键（同设备同排版设置命中缓存）。
  static String cacheKey(TypesetMeasureParams params) {
    final hash = Object.hash(
      params.width,
      params.height,
      params.pagePadding,
      params.contentVerticalPadding,
      params.fontSize,
      params.lineHeight,
      params.letterSpacing,
      params.fontFamily,
      params.devicePixelRatio,
      params.baselineAlign,
      params.firstLineIndentChars,
    );
    return '$_keyPrefix$hash';
  }

  static CalibrationData? load(PreferencesService prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return CalibrationData.fromJson(json);
    } catch (e) {
      Logging.warning('[LayoutCalib] cache decode failed key=$key: $e');
      return null;
    }
  }

  static Future<void> save(
    PreferencesService prefs,
    String key,
    CalibrationData data,
  ) async {
    await prefs.setString(key, jsonEncode(data.toJson()));
    Logging.info('[LayoutCalib] cache saved key=$key');
  }

  static Future<void> remove(PreferencesService prefs, String key) async {
    await prefs.remove(key);
  }
}
