// test/features/profile/other_settings_view_model_test.dart
//
// OtherSettingsViewModel — 无 FFI 依赖，纯 PreferencesService 持久化信号
//
// 覆盖：默认值、读写持久化、initialize 守卫、dispose
//
// 跳过：
//   - resetAllSettings() — 依赖 getIt<ReaderConfig>() + ThemeManager，需完整 DI 环境
//   - clearAllLocalData() — 依赖 SystemCache (path_provider + dart:io)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart';

class _MockSharedPreferences extends Mock implements PreferencesService {
  _MockSharedPreferences() {
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(
      () => getBool(any(), defaultValue: any(named: 'defaultValue')),
    ).thenReturn(null);
    when(() => getString(any())).thenReturn(null);
  }
}

void main() {
  late _MockSharedPreferences mockPrefs;
  late OtherSettingsViewModel vm;

  setUp(() {
    mockPrefs = _MockSharedPreferences();
    vm = OtherSettingsViewModel(mockPrefs);
  });

  group('OtherSettingsViewModel initial values', () {
    test('notificationsEnabled defaults to true', () {
      expect(vm.notificationsEnabled.value, true);
    });

    test('startupCheckEnabled defaults to true', () {
      expect(vm.startupCheckEnabled.value, true);
    });

    test('markdownPreview defaults to false', () {
      expect(vm.markdownPreview.value, false);
    });
  });

  group('OtherSettingsViewModel initialize', () {
    test('initialize does not throw in test environment', () {
      // initialize 不再加载 PackageInfo
      expect(vm.initialize(), completes);
    });

    test('initialize guards against double call', () async {
      await vm.initialize();
      // 第二次调用不应抛异常
      await vm.initialize();
    });
  });

  group('OtherSettingsViewModel value changes', () {
    test('notificationsEnabled change updates signal', () {
      vm.notificationsEnabled.value = false;
      expect(vm.notificationsEnabled.value, false);
    });

    test('startupCheckEnabled change updates signal', () {
      vm.startupCheckEnabled.value = false;
      expect(vm.startupCheckEnabled.value, false);
    });

    test('markdownPreview change updates signal', () {
      vm.markdownPreview.value = true;
      expect(vm.markdownPreview.value, true);
    });

    test('notificationsEnabled persists after debounce', () async {
      vm.notificationsEnabled.value = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => mockPrefs.setBool(SettingsKeys.otherNotifications, false),
      ).called(1);
    });

    test('startupCheckEnabled persists after debounce', () async {
      vm.startupCheckEnabled.value = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => mockPrefs.setBool(SettingsKeys.otherStartupCheck, false),
      ).called(1);
    });

    test('markdownPreview persists after debounce', () async {
      vm.markdownPreview.value = true;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => mockPrefs.setBool(SettingsKeys.otherMarkdownPreview, true),
      ).called(1);
    });
  });

  group('OtherSettingsViewModel loading from persisted values', () {
    test('reads notificationsEnabled from PreferencesService', () {
      when(
        () => mockPrefs.getBool(
          SettingsKeys.otherNotifications,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(false);
      final vm2 = OtherSettingsViewModel(mockPrefs);
      expect(vm2.notificationsEnabled.value, false);
    });

    test('reads markdownPreview from PreferencesService', () {
      when(
        () => mockPrefs.getBool(
          SettingsKeys.otherMarkdownPreview,
          defaultValue: any(named: 'defaultValue'),
        ),
      ).thenReturn(true);
      final vm2 = OtherSettingsViewModel(mockPrefs);
      expect(vm2.markdownPreview.value, true);
    });
  });

  group('OtherSettingsViewModel dispose', () {
    test('dispose does not throw', () {
      expect(() => vm.dispose(), returnsNormally);
    });
  });
}
