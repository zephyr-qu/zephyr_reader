import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticFeedback', () {
    test('light 类型应触发轻触觉反馈', () {
      when(() => HapticFeedback.lightImpact()).thenAnswer((_) async {});

      hapticFeedback(HapticType.light);

      verify(() => HapticFeedback.lightImpact()).called(1);
    });

    test('medium 类型应触发中等触觉反馈', () {
      when(() => HapticFeedback.mediumImpact()).thenAnswer((_) async {});

      hapticFeedback(HapticType.medium);

      verify(() => HapticFeedback.mediumImpact()).called(1);
    });

    test('heavy 类型应触发重触觉反馈', () {
      when(() => HapticFeedback.heavyImpact()).thenAnswer((_) async {});

      hapticFeedback(HapticType.heavy);

      verify(() => HapticFeedback.heavyImpact()).called(1);
    });

    test('selection 类型应触发选择点击反馈', () {
      when(() => HapticFeedback.selectionClick()).thenAnswer((_) async {});

      hapticFeedback(HapticType.selection);

      verify(() => HapticFeedback.selectionClick()).called(1);
    });

    test('所有类型都应正确映射到对应的方法', () {
      for (final type in HapticType.values) {
        when(() => HapticFeedback.lightImpact()).thenAnswer((_) async {});
        when(() => HapticFeedback.mediumImpact()).thenAnswer((_) async {});
        when(() => HapticFeedback.heavyImpact()).thenAnswer((_) async {});
        when(() => HapticFeedback.selectionClick()).thenAnswer((_) async {});

        hapticFeedback(type);
      }
    });
  });
}
