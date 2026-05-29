import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/battery/battery_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BatteryStateService', () {
    late BatteryStateService service;

    setUp(() {
      service = BatteryStateService();
    });

    group('服务实例', () {
      test('应返回单例', () {
        final service1 = BatteryStateService();
        final service2 = BatteryStateService();
        expect(service1, identical(service2, service1));
      });
    });

    group('API 存在性测试', () {
      test('isCharging 方法存在', () {
        expect(() => service.isCharging(), returnsNormally);
      });

      test('getBatteryLevel 方法存在', () {
        expect(() => service.getBatteryLevel(), returnsNormally);
      });

      test('getBatteryState 方法存在', () {
        expect(() => service.getBatteryState(), returnsNormally);
      });

      test('listen 方法存在', () {
        expect(() => service.listen((state) {}), returnsNormally);
      });
    });

    group('返回值类型检查', () {
      test('isCharging 应返回 bool', () async {
        final result = await service.isCharging();
        expect(result, isA<bool>());
      });

      test('getBatteryLevel 应返回 int', () async {
        final level = await service.getBatteryLevel();
        expect(level, isA<int>());
      });

      test('getBatteryState 应返回完整状态', () async {
        final state = await service.getBatteryState();

        expect(state.isCharging, isA<bool>());
        expect(state.batteryLevel, isA<int>());
        expect(state.temperature, isA<double>());
      });
    });

    group('边界值测试', () {
      test('电量返回应在合理范围内', () async {
        final level = await service.getBatteryLevel();
        // 在非 Android 环境返回默认值 0
        // 在 Android 设备返回实际电量
        expect(level, greaterThanOrEqualTo(0));
        expect(level, lessThanOrEqualTo(100));
      });

      test('温度应为正数', () async {
        final state = await service.getBatteryState();
        // 在非 Android 环境返回默认值
        expect(state.temperature, greaterThanOrEqualTo(0));
      });
    });
  });
}
