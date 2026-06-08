import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';

void main() {
  group('AsyncStateSignalExt.loadAsync', () {
    test('加载成功应设置 value 状态并返回数据', () async {
      final signal = Signal<AsyncState<String>>(AsyncState<String>.loading());
      final result = await signal.loadAsync(() async => 'hello');

      expect(result, equals('hello'));
      expect(signal.value.hasValue, isTrue);
      expect(signal.value.value, equals('hello'));
      expect(signal.value.hasError, isFalse);
    });

    test('加载失败应设置 error 状态并返回 null', () async {
      final signal = Signal<AsyncState<String>>(AsyncState<String>.loading());
      final error = Exception('test error');
      final result = await signal.loadAsync(() async => throw error);

      expect(result, isNull);
      expect(signal.value.hasError, isTrue);
      expect(signal.value.hasValue, isFalse);
      expect(signal.value.error, isA<Exception>());
    });

    test('加载过程中应先进入 loading 状态', () async {
      final signal = Signal<AsyncState<String>>(AsyncState<String>.loading());
      final completer = Completer<String>();

      final future = signal.loadAsync(() async => completer.future);
      expect(signal.value.isLoading, isTrue);
      expect(signal.value.hasValue, isFalse);
      expect(signal.value.hasError, isFalse);

      completer.complete('done');
      await future;
      expect(signal.value.value, equals('done'));
    });

    test('label 被传递给日志（不抛异常即验证）', () async {
      final signal = Signal<AsyncState<int>>(AsyncState<int>.loading());
      final result = await signal.loadAsync(
        () async => 42,
        label: 'test-label',
      );
      expect(result, equals(42));
    });

    test('错误路径不因缺失 label 而抛异常', () async {
      final signal = Signal<AsyncState<double>>(AsyncState<double>.loading());
      final result = await signal.loadAsync(() async => throw Exception());
      expect(result, isNull);
      expect(signal.value.hasError, isTrue);
    });

    test('泛型 T 类型正确传递', () async {
      final signal = Signal<AsyncState<List<int>>>(
        AsyncState<List<int>>.loading(),
      );
      final result = await signal.loadAsync(() async => [1, 2, 3]);
      expect(result, equals([1, 2, 3]));
      expect(signal.value.value, equals([1, 2, 3]));
    });
  });
}
