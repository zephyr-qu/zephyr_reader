// test/features/profile/tts_settings_view_model_test.dart
//
// TtsSettingsViewModel — 无 FFI 依赖，纯 SharedPreferences 持久化信号
//
// 覆盖：默认值、读写持久化、dispose

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {
  _MockSharedPreferences() {
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => getDouble(any())).thenReturn(null);
    when(() => getBool(any())).thenReturn(null);
    when(() => getInt(any())).thenReturn(null);
  }
}

void main() {
  late _MockSharedPreferences mockPrefs;
  late TtsSettingsViewModel vm;

  setUp(() {
    mockPrefs = _MockSharedPreferences();
    vm = TtsSettingsViewModel(mockPrefs);
  });

  group('TtsSettingsViewModel initial values', () {
    test('speed defaults to 1.0', () {
      expect(vm.speed.value, 1.0);
    });

    test('pitch defaults to 1.0', () {
      expect(vm.pitch.value, 1.0);
    });

    test('pauseBetween defaults to 300', () {
      expect(vm.pauseBetween.value, 300);
    });

    test('bilingualAlternate defaults to true', () {
      expect(vm.bilingualAlternate.value, true);
    });

    test('originalOnly defaults to false', () {
      expect(vm.originalOnly.value, false);
    });

    test('switchInterval defaults to 500', () {
      expect(vm.switchInterval.value, 500);
    });

    test('backgroundPlay defaults to true', () {
      expect(vm.backgroundPlay.value, true);
    });

    test('autoPage defaults to true', () {
      expect(vm.autoPage.value, true);
    });

    test('highlightFollow defaults to true', () {
      expect(vm.highlightFollow.value, true);
    });

    test('dimOnLock defaults to false', () {
      expect(vm.dimOnLock.value, false);
    });
  });

  group('TtsSettingsViewModel value changes', () {
    test('speed change updates signal', () {
      vm.speed.value = 1.5;
      expect(vm.speed.value, 1.5);
    });

    test('pitch change updates signal', () {
      vm.pitch.value = 1.25;
      expect(vm.pitch.value, 1.25);
    });

    test('pauseBetween change updates signal', () {
      vm.pauseBetween.value = 500;
      expect(vm.pauseBetween.value, 500);
    });

    test('bilingualAlternate change updates signal', () {
      vm.bilingualAlternate.value = false;
      expect(vm.bilingualAlternate.value, false);
    });

    test('originalOnly change updates signal', () {
      vm.originalOnly.value = true;
      expect(vm.originalOnly.value, true);
    });

    test('switchInterval change updates signal', () {
      vm.switchInterval.value = 1000;
      expect(vm.switchInterval.value, 1000);
    });

    test('backgroundPlay change updates signal', () {
      vm.backgroundPlay.value = false;
      expect(vm.backgroundPlay.value, false);
    });

    test('autoPage change updates signal', () {
      vm.autoPage.value = false;
      expect(vm.autoPage.value, false);
    });

    test('highlightFollow change updates signal', () {
      vm.highlightFollow.value = false;
      expect(vm.highlightFollow.value, false);
    });

    test('dimOnLock change updates signal', () {
      vm.dimOnLock.value = true;
      expect(vm.dimOnLock.value, true);
    });

    test('speed persists after debounce', () async {
      vm.speed.value = 1.5;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(() => mockPrefs.setDouble(SettingsKeys.ttsSpeed, 1.5)).called(1);
    });

    test('bilingualAlternate persists after debounce', () async {
      vm.bilingualAlternate.value = false;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => mockPrefs.setBool(SettingsKeys.ttsBilingualAlternate, false),
      ).called(1);
    });

    test('pauseBetween persists after debounce', () async {
      vm.pauseBetween.value = 500;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      verify(
        () => mockPrefs.setInt(SettingsKeys.ttsPauseBetween, 500),
      ).called(1);
    });
  });

  group('TtsSettingsViewModel loading from persisted values', () {
    test('reads speed from SharedPreferences', () {
      when(() => mockPrefs.getDouble(SettingsKeys.ttsSpeed)).thenReturn(0.75);
      final vm2 = TtsSettingsViewModel(mockPrefs);
      expect(vm2.speed.value, 0.75);
    });

    test('reads bilingualAlternate from SharedPreferences', () {
      when(
        () => mockPrefs.getBool(SettingsKeys.ttsBilingualAlternate),
      ).thenReturn(false);
      final vm2 = TtsSettingsViewModel(mockPrefs);
      expect(vm2.bilingualAlternate.value, false);
    });

    test('reads pauseBetween from SharedPreferences', () {
      when(
        () => mockPrefs.getInt(SettingsKeys.ttsPauseBetween),
      ).thenReturn(800);
      final vm2 = TtsSettingsViewModel(mockPrefs);
      expect(vm2.pauseBetween.value, 800);
    });
  });

  group('TtsSettingsViewModel dispose', () {
    test('dispose does not throw', () {
      expect(() => vm.dispose(), returnsNormally);
    });
  });
}
