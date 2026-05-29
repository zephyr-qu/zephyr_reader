import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoThemeService', () {
    late AutoThemeService service;
    late MockSharedPreferences mockPrefs;

    setUp(() async {
      mockPrefs = _MockSharedPreferences();

      // 默认返回 false
      when(() => mockPrefs.getBool(any())).thenReturn(null);

      // 默认返回 null (使用默认值)
      when(() => mockPrefs.getInt(any())).thenReturn(null);

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
        verify(() => mockPrefs.setBool('auto_theme_enabled', true)).called(1);
      });

      test('disableAutoTheme 应禁用并重置为系统主题', () async {
        when(() => mockPrefs.getBool('auto_theme_enabled')).thenReturn(true);

        await service.disableAutoTheme();

        expect(service.autoThemeEnabled.value, isFalse);
        expect(service.themeMode.value, equals(ThemeMode.system));
        verify(() => mockPrefs.setBool('auto_theme_enabled', false)).called(1);
      });
    });

    group('深色模式时间设置', () {
      test('setDarkModeTime 应更新配置', () async {
        await service.setDarkModeTime(20, 7);

        expect(service.darkModeStartHour.value, equals(20));
        expect(service.darkModeEndHour.value, equals(7));

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
      test('getSunriseTime 应返回结束时间', () {
        final sunrise = service.getSunriseTime();
        expect(sunrise.inHours, equals(6));
      });

      test('getSunsetTime 应返回开始时间', () {
        final sunset = service.getSunsetTime();
        expect(sunset.inHours, equals(18));
      });

      test('修改时间后应反映新的日出日落', () async {
        await service.setDarkModeTime(20, 7);

        expect(service.getSunriseTime().inHours, equals(7));
        expect(service.getSunsetTime().inHours, equals(20));
      });
    });

    group('ThemeTimePreset', () {
      test('应从预设中正确选择', () {
        final preset = ThemeTimePreset.fromHours(18, 6);
        expect(preset, equals(ThemeTimePreset.sunsetToSunrise));
        expect(preset.displayName, equals('日落到日出'));
      });

      test('应匹配 eveningToMorning', () {
        final preset = ThemeTimePreset.fromHours(20, 7);
        expect(preset, equals(ThemeTimePreset.eveningToMorning));
      });

      test('不匹配时应返回自定义', () {
        final preset = ThemeTimePreset.fromHours(19, 8);
        expect(preset, equals(ThemeTimePreset.custom));
      });

      test('所有预设应有显示名称', () {
        for (final preset in ThemeTimePreset.values) {
          expect(preset.displayName, isNotEmpty);
        }
      });
    });

    // 注: _updateThemeMode 和 _startAutoSwitch 是私有方法
    // 通过 public API 间接测试其行为
  });
}
