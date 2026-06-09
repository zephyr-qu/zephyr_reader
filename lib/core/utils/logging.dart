/// 集中式日志工具。
///
/// 内部基于 [Logger] 实现，Release 模式下仅输出错误级别，
/// Debug 模式下使用 [PrettyPrinter] 格式化输出。
/// 项目中应统一使用此类，而非直接调用 `Logger`、`print` 或 `stderr`。
///
/// ## 文件输出
/// 调用 [init] 后，所有日志同时写入文件 `{docDir}/zephyr_reader/logs/app_*.log`。
/// 每启动一次应用生成一个新文件。未调用 [init] 时降级为仅控制台输出。
library;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class Logging {
  static Logger? _logger;
  static File? _logFile;

  /// 当前日志文件的路径，未初始化时为 `null`。
  static String? get logFilePath => _logFile?.path;

  /// 初始化日志系统，启用文件输出。
  ///
  /// 应在应用启动早期（[main] 内）调用一次。日志文件保存在
  /// `{应用文档目录}/zephyr_reader/logs/app_YYYY-MM-DDTHH-MM-SS.log`。
  static Future<void> init() async {
    if (_logger != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/zephyr_reader/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    _logFile = File('${logDir.path}/app_$timestamp.log');

    final printer = kReleaseMode
        ? null
        : PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 8,
            lineLength: 120,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          );

    _logger = Logger(
      printer: printer,
      output: MultiOutput([ConsoleOutput(), FileOutput(file: _logFile!)]),
    );
  }

  static Logger get _instance =>
      _logger ??= Logger(
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
    _instance.i(message);
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
        _instance.e(message, error: exception, stackTrace: stackTrace);
      } else if (exception != null) {
        _instance.e(message, error: exception);
      } else {
        _instance.e(message);
      }
    } catch (e) {
      stderr.writeln('[Logging.error]  (logger threw: $e)');
    }
  }

  /// 记录调试级别日志。
  ///
  /// [message] 日志内容。
  static void debug(String message) {
    _instance.d(message);
  }

  /// 记录警告级别日志。
  ///
  /// [message] 日志内容。
  static void warning(String message) {
    _instance.w(message);
  }
}
