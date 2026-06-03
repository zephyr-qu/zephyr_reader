import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';

@injectable
class ThemeBrightnessViewModel {
  final SharedPreferences _prefs;
  final _themeManager = ThemeManager.instance;
  final _readerConfig = getIt<ReaderConfig>();

  final themeType = signal<AppThemeType>(AppThemeType.light);
  final readerBgColorIndex = signal<int>(0);
  late final brightness = persistedInt(_prefs, SettingsKeys.brightness, 80);
  late final useSystemBrightness = persistedBool(
    _prefs, SettingsKeys.useSystemBrightness, true,
  );
  final currentPresetId = signal<String?>(null);

  bool _initialized = false;

  ThemeBrightnessViewModel(this._prefs);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    themeType.value = _themeManager.themeType.value;
    currentPresetId.value = _themeManager.currentPresetId.value;
    readerBgColorIndex.value = _readerConfig.readerBgColorIndex.value;
  }

  Future<void> setThemeType(AppThemeType type) async {
    themeType.value = type;
    _themeManager.themeType.value = type;
  }

  Future<void> setReaderBgColorIndex(int index) async {
    readerBgColorIndex.value = index;
    _readerConfig.readerBgColorIndex.value = index;
  }

  Future<void> setBrightness(int value) async {
    brightness.value = value.clamp(30, 100);
  }

  Future<void> setUseSystemBrightness(bool value) async {
    useSystemBrightness.value = value;
  }

  List<ThemePreset> get presets => _themeManager.getAvailablePresets();

  Future<void> applyPreset(String presetId) async {
    currentPresetId.value = presetId;
    await _themeManager.applyPreset(presetId);
  }
}