// lib/di/network_module.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/error/api_error.dart';
import 'package:zephyr_reader/shared/utils/logging.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

@module
abstract class NetworkModule {
  @LazySingleton()
  Dio get dio => _createDio();

  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        responseType: ResponseType.json,
        connectTimeout: const Duration(seconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: AppConfig.receiveTimeout),
        headers: AppConfig.defaultHeaders,
      ),
    );

    _setupInterceptors(dio);
    return dio;
  }

  /// 配置 Dio 拦截器
  void _setupInterceptors(Dio dio) {
    // 重试拦截器
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: AppConfig.retries,
        retryDelays: const [
          Duration(milliseconds: AppConfig.retryDelaysTimeout),
          Duration(microseconds: AppConfig.retryDelaysTimeout * 2),
          Duration(microseconds: AppConfig.retryDelaysTimeout * 4),
        ],
        retryEvaluator: (err, _) => err.type != DioExceptionType.cancel,
      ),
    );

    // 日志拦截器
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );

    // 业务拦截器
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 可在此添加通用参数（如设备ID）
          // options.queryParameters['device_id'] = AppConfig.deviceId;
          return handler.next(options);
        },
        onResponse: (response, handler) {
          // 可在此添加统一业务状态码处理
          if (response.data.runtimeType == String) {
            response.data = json.decode(response.data);
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          final apiError = handleError(error);
          Logging.error(apiError.toString());
          return handler.next(error);
        },
      ),
    );
  }
}
