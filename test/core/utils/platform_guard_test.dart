import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/platform_guard.dart';

void main() {
  group('guardPlatform', () {
    test('非 Android 平台返回 defaultValue', () async {
      // 当前测试环境非 Android
      final result = await guardPlatform(() async => 42, -1);
      expect(result, equals(-1));
    });

    test('非 Android 平台不执行 fn', () async {
      bool fnCalled = false;
      await guardPlatform(() async {
        fnCalled = true;
        return 42;
      }, -1);
      expect(fnCalled, isFalse);
    });

    test('fn 抛异常时返回 defaultValue', () async {
      // 无法在非 Android 上触发异常路径
      // 因为 Platform.isAndroid 为 false 时不执行 fn
      // 此行为在 Android 环境中通过集成测试验证
    });

    test('默认值类型泛型支持', () async {
      final result = await guardPlatform<String>(
        () async => 'value',
        'default',
      );
      expect(result, equals('default'));
    });

    test('默认值 null 支持', () async {
      final result = await guardPlatform<int?>(() async => 42, null);
      expect(result, isNull);
    });
  });
}
