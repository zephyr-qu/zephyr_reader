/// 集中式日志工具。
///
/// 内部基于 [Logger] 实现，Release 模式下仅输出错误级别，
/// Debug 模式下使用 [PrettyPrinter] 格式化输出。
/// 项目中应统一使用此类，而非直接调用 `Logger`、`print` 或 `stderr`。

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';
import 'dart:io';

class Logging {
  static final _logger = Logger(
    printer: kReleaseMode
        ? null
        : PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
  );

  /// 记录信息级别日志。
  ///
  /// [message] 日志内容。
  static void info(String message) {
    _logger.i(message);
  }

  /// 记录错误级别日志。
  ///
  /// [message] 错误描述；[exception] 异常对象（可选）；[stackTrace] 堆栈信息（可选）。
  static void error(
    String message, {
    Object? exception,
    StackTrace? stackTrace,
  }) {
    try {
      if (exception != null && stackTrace != null) {
        _logger.e(message, error: exception, stackTrace: stackTrace);
      } else if (exception != null) {
        _logger.e(message, error: exception);
      } else {
        _logger.e(message);
      }
    } catch (e) {
      stderr.writeln('[Logging.error]  (logger threw: $e)');
    }
  }

  /// 记录调试级别日志。
  ///
  /// [message] 日志内容。
  static void debug(String message) {
    _logger.d(message);
  }

  /// 记录警告级别日志。
  ///
  /// [message] 日志内容。
  static void warning(String message) {
    _logger.w(message);
  }
}
