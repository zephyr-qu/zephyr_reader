import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/utils/device_id.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('getOrCreateDeviceId', () {
    test('首次调用应创建并返回新 ID', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final id = await getOrCreateDeviceId(prefs);

      expect(id, isNotEmpty);
      expect(id.split('-').length, equals(5));
    });

    test('同一实例返回相同的 ID', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final id1 = await getOrCreateDeviceId(prefs);
      final id2 = await getOrCreateDeviceId(prefs);

      expect(id1, equals(id2));
    });

    test('重复调用返回已保存的 ID', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.device.id': 'existing-uuid-value',
      });
      final prefs = await SharedPreferences.getInstance();

      final id = await getOrCreateDeviceId(prefs);

      expect(id, equals('existing-uuid-value'));
    });

    test('保存空字符串时应重新生成', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.device.id': '',
      });
      final prefs = await SharedPreferences.getInstance();

      final id = await getOrCreateDeviceId(prefs);

      expect(id, isNotEmpty);
      expect(id, isNot(equals('')));
    });

    test('生成的 ID 符合 UUID v4 格式', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final id = await getOrCreateDeviceId(prefs);

      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidPattern.hasMatch(id), isTrue, reason: '$id 不是有效的 UUID v4');
    });
  });
}
