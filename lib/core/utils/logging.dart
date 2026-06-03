import 'package:logger/logger.dart';
import 'dart:io';

class Logging {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static void info(String message) {
    _logger.i(message);
  }

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
      // Logger 自身异常时 fallback 到 stderr，不静默丢失
      stderr.writeln('[Logging.error]  (logger threw: )');
    }
  }

  static void debug(String message) {
    _logger.d(message);
  }

  static void warning(String message) {
    _logger.w(message);
  }
}
