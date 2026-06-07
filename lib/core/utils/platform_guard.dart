/// Android 平台安全执行辅助。
///
/// 用于封装仅在 Android 平台有效的 API 调用以防止跨平台崩溃。

import 'dart:io';
import './logging.dart';

/// 在 Android 平台安全执行操作，非 Android 平台直接返回默认值。
///
/// [fn] 仅在 [Platform.isAndroid] 为 true 时执行；
/// 抛出异常时记录日志并返回 [defaultValue]，不向上传播。
Future<T> guardAndroid<T>(Future<T> Function() fn, T defaultValue) async {
  if (!Platform.isAndroid) return defaultValue;
  try {
    return await fn();
  } catch (e) {
    Logging.error('guardAndroid: 平台操作失败', exception: e);
    return defaultValue;
  }
}
