import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

@module
abstract class NetworkModule {
  @LazySingleton()
  Dio get dio => _createDio();

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.com',
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors(dio);
    return dio;
  }

  void _setupInterceptors(Dio dio) {
    // 简单重试（最大 3 次，指数退避），代替 dio_smart_retry
    dio.interceptors.add(_SimpleRetryInterceptor());

    // 调试日志（Dio 内置，代替 pretty_dio_logger）
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );

    // 统一错误日志
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          Logging.error('HTTP ${error.type.name}: ${error.message}');
          return handler.next(error);
        },
      ),
    );
  }
}

/// 轻量重试拦截器，不依赖 dio_smart_retry
class _SimpleRetryInterceptor extends Interceptor {
  static const _maxRetries = 3;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.type == DioExceptionType.cancel) {
      return handler.next(err);
    }

    final retryCount =
        (err.requestOptions.extra['_retryCount'] as int? ?? 0) + 1;
    if (retryCount > _maxRetries) {
      return handler.next(err);
    }

    err.requestOptions.extra['_retryCount'] = retryCount;

    // 指数退避: 500ms, 1s, 2s
    await Future<void>.delayed(
      Duration(milliseconds: 500 * (1 << (retryCount - 1))),
    );

    try {
      final response = await Dio().fetch<dynamic>(err.requestOptions);
      return handler.resolve(response);
    } catch (e) {
      Logging.warning('HTTP 重试仍失败，传递给下一个处理器: $e');
      return handler.next(err);
    }
  }
}
