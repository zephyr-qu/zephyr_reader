/// 在 Android 平台安全执行操作，非 Android 平台直接返回默认值。
///
/// 用于调用 Android 平台特有 API（如 Activity、Intent），防止在其他平台上抛出异常。
///
/// 参数 [fn] 仅在 `Platform.isAndroid == true` 时执行；
/// 抛出异常时记录日志并返回 [defaultValue]，不向上传播。
library;

import 'dart:io';
import './logging.dart';

Future<T> guardAndroid<T>(Future<T> Function() fn, T defaultValue) async {
  if (!Platform.isAndroid) return defaultValue;
  try {
    return await fn();
  } catch (e) {
    Logging.error('guardAndroid: 平台操作失败', exception: e);
    return defaultValue;
  }
}
