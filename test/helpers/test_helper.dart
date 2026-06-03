import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 测试辅助工具集
///
/// 提供常用的测试 helper 函数，简化测试编写
class TestHelper {
  // ===== AsyncState 辅助方法 =====

  /// 创建成功的数据状态
  static AsyncState<T> dataState<T>(T data) => AsyncState.data(data);

  /// 创建加载中的状态
  static AsyncState<dynamic> loadingState<T>() => AsyncState.loading();

  /// 创建错误状态
  static AsyncState<dynamic> errorState<T>(Object error, [StackTrace? stack]) =>
      AsyncState.error(error, stack ?? StackTrace.current);

  /// 验证 AsyncState 是否为加载中
  static void expectLoading<T>(AsyncData<T> state) {
    expect(state, equals(AsyncState.loading()));
    expect(state.isLoading, isTrue);
    expect(state.hasValue, isFalse);
    expect(state.hasError, isFalse);
  }

  /// 验证 AsyncState 是否有数据
  static void expectData<T>(AsyncData<T> state, T expected) {
    expect(state, equals(AsyncState.data(expected)));
    expect(state.hasValue, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.hasError, isFalse);
  }

  /// 验证 AsyncState 是否出错
  static void expectError<T>(AsyncData<T> state, [String? errorContains]) {
    expect(state.hasError, isTrue);
    if (errorContains != null) {
      expect(state.errorMessage.contains(errorContains), isTrue);
    }
  }

  // ===== Mock 辅助方法 =====

  /// 注册常见的 fallback 值
  static void registerCommonFallbacks() {
    registerFallbackValue(String);
    registerFallbackValue(0);
    registerFallbackValue(0.0);
    registerFallbackValue(false);
    registerFallbackValue(DateTime.now());
  }

  // ===== 等待辅助方法 =====

  /// 等待并完成所有动画
  static Future<void> pumpAndSettleFast(
    WidgetTester tester, {
    Duration step = const Duration(milliseconds: 50),
    int maxSteps = 20,
  }) async {
    for (int i = 0; i < maxSteps; i++) {
      await tester.pump(step);
    }
    await tester.pumpAndSettle();
  }

  /// 查找特定类型的 widget
  static T findWidget<T>(WidgetTester tester) {
    final found = find.byType(T).evaluate();
    expect(found, isNotEmpty, reason: '找不到 $T 类型的 widget');
    return tester.widget(find.byType(T));
  }

  // ===== 性能测试辅助 =====

  /// 测量异步操作耗时
  static Future<T> measure<T>(
    String testName,
    Future<T> Function() action,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await action();
    stopwatch.stop();

    Logging.info('⏱️ $testName: ${stopwatch.elapsedMilliseconds}ms');

    // 性能警告: 超过1秒的操作
    if (stopwatch.elapsedMilliseconds > 1000) {
      Logging.warning('⚠️ 警告: $testName 超过1秒');
    }

    return result;
  }

  /// 测试并发操作的性能
  static Future<List<T>> benchmark<T>(
    String testName,
    int iterations,
    Future<T> Function(int i) operation,
  ) async {
    final stopwatch = Stopwatch()..start();

    final results = await Future.wait(
      List.generate(iterations, (i) => operation(i)),
    );

    stopwatch.stop();
    Logging.info(
      '📊 $testName ($iterations次): ${stopwatch.elapsedMilliseconds}ms',
    );
    Logging.info('   平均: ${stopwatch.elapsedMilliseconds / iterations}ms/次');

    return results;
  }
}

// ===== 扩展方法 =====

extension on AsyncState<Object?> {
  /// 获取错误消息 (如果有)
  String get errorMessage {
    if (this is AsyncError) {
      return (this as AsyncError).error.toString();
    }
    return '';
  }
}
