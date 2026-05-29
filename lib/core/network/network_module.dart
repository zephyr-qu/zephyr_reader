import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:sentry_dio/sentry_dio.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/network/network_error.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
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
        connectTimeout: const Duration(
          seconds: AppConfig.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConfig.receiveTimeoutSeconds,
        ),
        headers: AppConfig.defaultHeaders,
      ),
    );

    _setupInterceptors(dio);
    return dio;
  }

  void _setupInterceptors(Dio dio) {
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: AppConfig.retries,
        retryDelays: const [
          Duration(milliseconds: 500),
          Duration(milliseconds: 1000),
          Duration(milliseconds: 2000),
        ],
        retryEvaluator: (err, _) => err.type != DioExceptionType.cancel,
      ),
    );

    dio.addSentry();

    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: kDebugMode,
        responseBody: kDebugMode,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.data.runtimeType == String) {
            response.data =
                json.decode(response.data as String) as Map<String, dynamic>;
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
