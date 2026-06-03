import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticFeedback', () {
    test('light 类型应不抛异常', () {
      expect(() => hapticFeedback(HapticType.light), returnsNormally);
    });

    test('medium 类型应不抛异常', () {
      expect(() => hapticFeedback(HapticType.medium), returnsNormally);
    });

    test('heavy 类型应不抛异常', () {
      expect(() => hapticFeedback(HapticType.heavy), returnsNormally);
    });

    test('selection 类型应不抛异常', () {
      expect(() => hapticFeedback(HapticType.selection), returnsNormally);
    });

    test('所有类型都应正确映射到对应的方法', () {
      expect(() => HapticType.values.forEach(hapticFeedback), returnsNormally);
    });
  });
}
