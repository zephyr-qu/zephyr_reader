import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension RouterContext on BuildContext {
  Future<T?> goToWith<T>({
    required String name,
    Map<String, String> pathParams = const {},
    Map<String, dynamic> queryParams = const {},
    Object? extra,
  }) {
    return pushNamed<T>(
      name,
      pathParameters: pathParams,
      queryParameters: _toStringMap(queryParams),
      extra: extra,
    );
  }

  void goTo(
    String name, {
    Map<String, String> pathParams = const {},
    Map<String, dynamic> queryParams = const {},
    Object? extra,
  }) {
    pushNamed(
      name,
      pathParameters: pathParams,
      queryParameters: _toStringMap(queryParams),
      extra: extra,
    );
  }

  void replaceTo(
    String name, {
    Map<String, String> pathParams = const {},
    Map<String, dynamic> queryParams = const {},
    Object? extra,
  }) {
    pushReplacementNamed(
      name,
      pathParameters: pathParams,
      queryParameters: _toStringMap(queryParams),
      extra: extra,
    );
  }

  void goRoot(
    String name, {
    Map<String, String> pathParams = const {},
    Map<String, dynamic> queryParams = const {},
    Object? extra,
  }) {
    goNamed(
      name,
      pathParameters: pathParams,
      queryParameters: _toStringMap(queryParams),
      extra: extra,
    );
  }

  /// 返回并携带结果
  void backWith<T>([T? result]) => pop(result);
}

extension GoRouterStateX on GoRouterState {
  String getString(String key) => pathParameters[key] ?? '';

  int getInt(String key, {int defaultValue = 0}) =>
      int.tryParse(pathParameters[key] ?? '') ?? defaultValue;

  String getQuery(String key, {String? defaultValue}) =>
      uri.queryParameters[key] ?? defaultValue ?? '';
}

Map<String, String> _toStringMap(Map<String, dynamic> input) {
  return input.map((key, value) => MapEntry(key, value.toString()));
}
