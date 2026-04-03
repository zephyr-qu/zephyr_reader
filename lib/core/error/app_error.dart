/// 应用错误类型
///
/// 定义所有可能的错误分类，便于统一处理和用户提示
enum ErrorType {
  /// 网络错误
  network('网络错误', '请检查网络连接后重试'),

  /// 数据库错误
  database('数据错误', '数据操作失败，请重试'),

  /// 文件操作错误
  file('文件错误', '文件操作失败，请检查存储空间'),

  /// 解析错误
  parse('解析错误', '文件格式不支持或已损坏'),

  /// 权限错误
  permission('权限错误', '请授予必要的应用权限'),

  /// 未找到
  notFound('未找到', '请求的内容不存在'),

  /// 验证错误
  validation('输入错误', '请检查输入内容'),

  /// 未知错误
  unknown('未知错误', '发生未知错误，请重试'),

  /// 取消操作
  cancelled('已取消', '操作已取消'),

  /// 超时
  timeout('超时', '操作超时，请重试');

  final String displayName;
  final String defaultMessage;

  const ErrorType(this.displayName, this.defaultMessage);
}

/// 应用错误类
///
/// 统一封装应用中的所有错误，包含类型、消息、原始异常和堆栈
class AppError implements Exception {
  /// 错误类型
  final ErrorType type;

  /// 错误消息（用户友好）
  final String message;

  /// 详细错误信息（调试用）
  final String? detail;

  /// 原始异常
  final Object? originalError;

  /// 堆栈信息
  final StackTrace? stackTrace;

  /// 错误码（可选，用于特定错误识别）
  final String? code;

  /// 额外数据（可选）
  final Map<String, dynamic>? extraData;

  AppError({
    required this.type,
    required this.message,
    this.detail,
    this.originalError,
    this.stackTrace,
    this.code,
    this.extraData,
  });

  /// 创建网络错误
  factory AppError.network({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
  }) => AppError(
    type: ErrorType.network,
    message: message ?? ErrorType.network.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// 创建数据库错误
  factory AppError.database({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
  }) => AppError(
    type: ErrorType.database,
    message: message ?? ErrorType.database.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// 创建文件错误
  factory AppError.file({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
    String? path,
  }) => AppError(
    type: ErrorType.file,
    message: message ?? ErrorType.file.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
    extraData: path != null ? {'path': path} : null,
  );

  /// 创建验证错误
  factory AppError.validation({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
  }) => AppError(
    type: ErrorType.validation,
    message: message ?? ErrorType.validation.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// 创建取消错误
  factory AppError.cancelled({String? message, String? detail}) => AppError(
    type: ErrorType.cancelled,
    message: message ?? ErrorType.cancelled.defaultMessage,
    detail: detail,
  );

  /// 创建超时错误
  factory AppError.timeout({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
  }) => AppError(
    type: ErrorType.timeout,
    message: message ?? ErrorType.timeout.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
  );

  /// 创建解析错误
  factory AppError.parse({
    String? message,
    String? detail,
    Object? originalError,
    StackTrace? stackTrace,
    String? filePath,
  }) => AppError(
    type: ErrorType.parse,
    message: message ?? ErrorType.parse.defaultMessage,
    detail: detail,
    originalError: originalError,
    stackTrace: stackTrace,
    extraData: filePath != null ? {'filePath': filePath} : null,
  );

  /// 创建未找到错误
  factory AppError.notFound({
    String? message,
    String? detail,
    String? resource,
  }) => AppError(
    type: ErrorType.notFound,
    message: message ?? ErrorType.notFound.defaultMessage,
    detail: detail,
    extraData: resource != null ? {'resource': resource} : null,
  );

  /// 从未知异常创建
  factory AppError.fromException(
    Object error, {
    StackTrace? stackTrace,
    ErrorType defaultType = ErrorType.unknown,
  }) {
    // 如果已经是 AppError，直接返回
    if (error is AppError) return error;

    // 根据异常类型判断
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('network')) {
      return AppError.network(
        detail: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('database') ||
        errorString.contains('sqlite') ||
        errorString.contains('sql')) {
      return AppError.database(
        detail: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('file') ||
        errorString.contains('permission') ||
        errorString.contains('path') ||
        errorString.contains('no such file')) {
      return AppError.file(
        detail: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('parse') ||
        errorString.contains('format') ||
        errorString.contains('encoding')) {
      return AppError.parse(
        detail: error.toString(),
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return AppError(
      type: defaultType,
      message: defaultType.defaultMessage,
      detail: error.toString(),
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('AppError: ${type.displayName}');
    buffer.writeln('Message: $message');
    if (detail != null) buffer.writeln('Detail: $detail');
    if (code != null) buffer.writeln('Code: $code');
    if (originalError != null) buffer.writeln('Original: $originalError');
    return buffer.toString();
  }
}

/// 结果类型
///
/// 类似 Rust 的 `Result<T, E>`，用于明确表示可能失败的操作
sealed class Result<T> {
  const Result();

  /// 成功值
  T? get value => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => null,
  };

  /// 错误
  AppError? get error => switch (this) {
    Success<T>() => null,
    Failure<T>(error: final e) => e,
  };

  /// 是否成功
  bool get isSuccess => this is Success<T>;

  /// 是否失败
  bool get isFailure => this is Failure<T>;

  /// 获取成功值或抛出异常
  T getOrThrow() => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>(error: final e) => throw e,
  };

  /// 获取成功值或返回默认值
  T getOrElse(T defaultValue) => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>() => defaultValue,
  };

  /// 获取成功值或计算默认值
  T getOrCompute(T Function(AppError) fn) => switch (this) {
    Success<T>(value: final v) => v,
    Failure<T>(error: final e) => fn(e),
  };

  /// 映射成功值
  Result<R> map<R>(R Function(T) fn) => switch (this) {
    Success<T>(value: final v) => Result.success(fn(v)),
    Failure<T>(error: final e) => Result.failure(e),
  };

  /// 链式操作
  Result<R> flatMap<R>(Result<R> Function(T) fn) => switch (this) {
    Success<T>(value: final v) => fn(v),
    Failure<T>(error: final e) => Result.failure(e),
  };

  /// 创建成功结果
  factory Result.success(T value) = Success<T>;

  /// 创建失败结果
  factory Result.failure(AppError error) = Failure<T>;

  /// 捕获异常并转换为结果
  static Result<T> guard<T>(T Function() fn) {
    try {
      return Result.success(fn());
    } catch (e, stack) {
      return Result.failure(AppError.fromException(e, stackTrace: stack));
    }
  }

  /// 异步捕获异常
  static Future<Result<T>> guardAsync<T>(Future<T> Function() fn) async {
    try {
      return Result.success(await fn());
    } catch (e, stack) {
      return Result.failure(AppError.fromException(e, stackTrace: stack));
    }
  }
}

/// 成功结果
class Success<T> extends Result<T> {
  @override
  final T value;
  const Success(this.value);
}

/// 失败结果
class Failure<T> extends Result<T> {
  @override
  final AppError error;
  const Failure(this.error);
}
