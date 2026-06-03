import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/network/network_state_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkStateService', () {
    late NetworkStateService service;

    setUp(() {
      service = NetworkStateService();
    });

    group('服务实例', () {
      test('应返回单例', () {
        final service1 = NetworkStateService();
        final service2 = NetworkStateService();
      expect(identical(service1, service2), isTrue);
      });
    });

    // 注意：以下测试需要在 Android 设备上运行或使用 mock
    // 这里主要验证 API 存在性和基本行为

    group('API 存在性测试', () {
      test('isOnWifi 方法存在', () {
        expect(() => service.isOnWifi(), returnsNormally);
      });

      test('isConnected 方法存在', () {
        expect(() => service.isConnected(), returnsNormally);
      });

      test('getWifiState 方法存在', () {
        expect(() => service.getWifiState(), returnsNormally);
      });

      test('listen 方法存在', () {
        // listen 方法需要一个回调函数
        expect(() => service.listen((state) {}), returnsNormally);
      });
    });

    group('返回值类型检查', () {
      test('isOnWifi 应返回 bool', () async {
        final result = await service.isOnWifi();
        expect(result, isA<bool>());
      });

      test('isConnected 应返回 bool', () async {
        final result = await service.isConnected();
        expect(result, isA<bool>());
      });

      test('getWifiState 应返回 WifiState', () async {
        final state = await service.getWifiState();
        expect(state, isNotNull);
        expect(state.isConnected, isA<bool>());
        expect(state.isEnabled, isA<bool>());
      });
    });
  });
}
