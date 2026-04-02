/// 错误处理器
///
/// 统一处理应用中的错误，提供：
/// - 用户友好的错误提示（SnackBar/Dialog）
/// - 错误日志记录
/// - 错误上报（可选）
/// - 恢复策略
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'app_error.dart';

/// 错误处理器
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// 全局 BuildContext（需在 MaterialApp 中设置）
  BuildContext? _globalContext;

  /// 设置全局上下文
  void setGlobalContext(BuildContext context) {
    _globalContext = context;
  }

  /// 清除全局上下文
  void clearGlobalContext() {
    _globalContext = null;
  }

  /// 处理错误
  ///
  /// 根据错误类型决定如何显示和处理
  void handleError(
    AppError error, {
    BuildContext? context,
    bool showToast = true,
    bool logError = true,
    VoidCallback? onRetry,
  }) {
    final ctx = context ?? _globalContext;

    // 记录错误日志
    if (logError) {
      _logError(error);
    }

    // 显示用户提示
    if (showToast && ctx != null && ctx.mounted) {
      _showErrorSnackBar(ctx, error, onRetry: onRetry);
    }
  }

  /// 处理异常（自动转换）
  void handleException(
    Object exception, {
    BuildContext? context,
    StackTrace? stackTrace,
    bool showToast = true,
    bool logError = true,
    VoidCallback? onRetry,
  }) {
    final error = AppError.fromException(exception, stackTrace: stackTrace);
    handleError(
      error,
      context: context,
      showToast: showToast,
      logError: logError,
      onRetry: onRetry,
    );
  }

  /// 记录错误日志
  void _logError(AppError error) {
    final buffer = StringBuffer();
    buffer.writeln('╔═══════════════════════════════════════════════════════════');
    buffer.writeln('║ ERROR: ${error.type.displayName}');
    buffer.writeln('╠═══════════════════════════════════════════════════════════');
    buffer.writeln('║ Message: ${error.message}');
    if (error.detail != null) {
      buffer.writeln('║ Detail: ${error.detail}');
    }
    if (error.code != null) {
      buffer.writeln('║ Code: ${error.code}');
    }
    if (error.extraData != null) {
      buffer.writeln('║ Extra: ${error.extraData}');
    }
    if (error.originalError != null) {
      buffer.writeln('║ Original: ${error.originalError}');
    }
    if (error.stackTrace != null) {
      buffer.writeln('╠═══════════════════════════════════════════════════════════');
      buffer.writeln('║ Stack Trace:');
      buffer.writeln('${error.stackTrace}');
    }
    buffer.writeln('╚═══════════════════════════════════════════════════════════');

    Logging.error(buffer.toString());
  }

  /// 显示错误 SnackBar
  void _showErrorSnackBar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.type),
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                error.message,
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: onRetry != null ? 5 : 3),
        action: onRetry != null
            ? SnackBarAction(
                label: '重试',
                textColor: colorScheme.onErrorContainer,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onRetry();
                },
              )
            : null,
      ),
    );
  }

  /// 显示错误对话框（用于严重错误）
  Future<void> showErrorDialog(
    BuildContext context,
    AppError error, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
  }) async {
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          _getErrorIcon(error.type),
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: Text(title ?? error.type.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.message),
            if (error.detail != null && error.detail!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error.detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          if (onCancel != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onCancel();
              },
              child: const Text('取消'),
            ),
          if (onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: const Text('重试'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
        ],
      ),
    );
  }

  /// 获取错误图标
  IconData _getErrorIcon(ErrorType type) {
    return switch (type) {
      ErrorType.network => Icons.wifi_off_rounded,
      ErrorType.database => Icons.storage_rounded,
      ErrorType.file => Icons.folder_off_rounded,
      ErrorType.parse => Icons.code_off_rounded,
      ErrorType.permission => Icons.lock_rounded,
      ErrorType.notFound => Icons.search_off_rounded,
      ErrorType.validation => Icons.error_outline_rounded,
      ErrorType.timeout => Icons.timer_off_rounded,
      ErrorType.cancelled => Icons.cancel_outlined,
      ErrorType.unknown => Icons.error_outline_rounded,
    };
  }
}

/// 便捷扩展方法
extension ResultErrorHandler<T> on Result<T> {
  /// 处理错误并返回默认值
  T handleError({
    BuildContext? context,
    T? defaultValue,
    VoidCallback? onRetry,
  }) {
    if (isSuccess) return value as T;

    ErrorHandler().handleError(
      error!,
      context: context,
      onRetry: onRetry,
    );

    return defaultValue as T;
  }

  /// 显示错误并返回 null
  T? handleErrorNull({BuildContext? context}) {
    if (isSuccess) return value;

    ErrorHandler().handleError(error!, context: context);
    return null;
  }
}

/// Future 扩展
extension FutureErrorHandler<T> on Future<T> {
  /// 捕获异常并返回 Result
  Future<Result<T>> toResult() async {
    try {
      return Result.success(await this);
    } catch (e, stack) {
      return Result.failure(AppError.fromException(e, stackTrace: stack));
    }
  }

  /// 捕获异常并处理
  Future<T?> handleError({
    BuildContext? context,
    T? defaultValue,
    VoidCallback? onRetry,
  }) async {
    try {
      return await this;
    } catch (e, stack) {
      final error = AppError.fromException(e, stackTrace: stack);
      ErrorHandler().handleError(
        error,
        context: context,
        onRetry: onRetry,
      );
      return defaultValue;
    }
  }
}
