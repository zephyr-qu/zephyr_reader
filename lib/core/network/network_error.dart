import 'package:dio/dio.dart';

ApiError handleError(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.receiveTimeout => ApiError.timeout,
  DioExceptionType.connectionError => ApiError.offline,
  DioExceptionType.badResponse => switch (e.response?.statusCode) {
    401 => ApiError.unauthorized,
    403 => ApiError.forbidden,
    404 => ApiError.notFound,
    500 => ApiError.server,
    _ => ApiError.unknown(e.response?.statusMessage),
  },
  _ => ApiError.unknown(e.message),
};

// 错误类型（密封类）
sealed class ApiError implements Exception {
  const ApiError();
  static const timeout = _Timeout();
  static const offline = _Offline();
  static const unauthorized = _Unauthorized();
  static const forbidden = _Forbidden();
  static const notFound = _NotFound();
  static const server = _ServerError();
  factory ApiError.unknown(String? msg) = _Unknown;
}

class _Timeout extends ApiError {
  const _Timeout();
}

class _Offline extends ApiError {
  const _Offline();
}

class _Unauthorized extends ApiError {
  const _Unauthorized();
}

class _Forbidden extends ApiError {
  const _Forbidden();
}

class _NotFound extends ApiError {
  const _NotFound();
}

class _ServerError extends ApiError {
  const _ServerError();
}

class _Unknown extends ApiError {
  final String? msg;
  const _Unknown(this.msg);
}
