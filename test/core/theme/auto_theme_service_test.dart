import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';

class _MockSharedPreferences extends Mock implements PreferencesService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoThemeService', () {
    late AutoThemeService service;
    late _MockSharedPreferences mockPrefs;

    setUp(() async {
      mockPrefs = _MockSharedPreferences();

      // 默认返回 false
      when(
        () =>
            mockPrefs.getBool(any(), defaultValue: any(named: 'defaultValue')),
      ).thenAnswer((inv) => inv.namedArguments[#defaultValue] as bool);

      when(
        () => mockPrefs.getInt(any(), defaultValue: any(named: 'defaultValue')),
      ).thenAnswer((inv) => inv.namedArguments[#defaultValue] as int);

      when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);

      service = AutoThemeService(mockPrefs);
    });

    group('初始状态', () {
      test('应使用默认设置', () {
        expect(service.autoThemeEnabled.value, isFalse);
        expect(service.darkModeStartHour.value, equals(18));
        expect(service.darkModeEndHour.value, equals(6));
        expect(service.themeMode.value, equals(ThemeMode.system));
      });
    });

    group('启用/禁用自动主题', () {
      test('enableAutoTheme 应启并保存设置', () async {
        await service.enableAutoTheme();

        expect(service.autoThemeEnabled.value, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        verify(() => mockPrefs.setBool('auto_theme_enabled', true)).called(1);
      });

      test('disableAutoTheme 应禁用并重置为系统主题', () async {
        // 先启用，确保信号值与目标值不同，触发持久化写入
        service.autoThemeEnabled.value = true;
        await Future<void>.delayed(const Duration(milliseconds: 200));

        await service.disableAutoTheme();

        expect(service.autoThemeEnabled.value, isFalse);
        expect(service.themeMode.value, equals(ThemeMode.system));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        verify(() => mockPrefs.setBool('auto_theme_enabled', false)).called(1);
      });
    });

    group('深色模式时间设置', () {
      test('setDarkModeTime 应更新配置', () async {
        await service.setDarkModeTime(20, 7);

        expect(service.darkModeStartHour.value, equals(20));
        expect(service.darkModeEndHour.value, equals(7));

        await Future<void>.delayed(const Duration(milliseconds: 200));
        verify(() => mockPrefs.setInt('dark_mode_start_hour', 20)).called(1);
        verify(() => mockPrefs.setInt('dark_mode_end_hour', 7)).called(1);
      });

      test('应能设置为任意小时', () async {
        await service.setDarkModeTime(21, 5);

        expect(service.darkModeStartHour.value, equals(21));
        expect(service.darkModeEndHour.value, equals(5));
      });
    });

    group('日出日落时间计算', () {
      test('日出时间应等于深色模式结束时间', () {
        expect(
          Duration(hours: service.darkModeEndHour.value).inHours,
          equals(6),
        );
      });

      test('日落时间应等于深色模式开始时间', () {
        expect(
          Duration(hours: service.darkModeStartHour.value).inHours,
          equals(18),
        );
      });

      test('修改时间后应反映新的日出日落', () async {
        await service.setDarkModeTime(20, 7);

        expect(
          Duration(hours: service.darkModeEndHour.value).inHours,
          equals(7),
        );
        expect(
          Duration(hours: service.darkModeStartHour.value).inHours,
          equals(20),
        );
      });
    });

    group('ThemeTimePreset', () {
      test('应从预设中正确选择', () {
        final preset = ThemeTimePreset.fromHours(18, 6);
        expect(preset, equals(ThemeTimePreset.sunsetToSunrise));
      });

      test('应匹配 eveningToMorning', () {
        final preset = ThemeTimePreset.fromHours(20, 7);
        expect(preset, equals(ThemeTimePreset.eveningToMorning));
      });

      test('不匹配时应返回自定义', () {
        final preset = ThemeTimePreset.fromHours(19, 8);
        expect(preset, equals(ThemeTimePreset.custom));
      });
    });

    // 注: _updateThemeMode 和 _startAutoSwitch 是私有方法
    // 通过 public API 间接测试其行为
  });
}
