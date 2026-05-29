import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';

class ThemeBrightnessViewModel {
  final _themeManager = ThemeManager.instance;
  final _readerConfig = getIt<ReaderConfig>();
  late final SharedPreferences _prefs;

  final themeType = signal<AppThemeType>(AppThemeType.light);
  final readerBgColorIndex = signal<int>(0);
  final brightness = signal<int>(80);
  final useSystemBrightness = signal<bool>(true);
  final lowBatteryDim = signal<bool>(false);
  final amoledMode = signal<bool>(false);
  final reduceWhitePoint = signal<bool>(false);

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = getIt<SharedPreferences>();
    themeType.value = _themeManager.themeType.value;
    readerBgColorIndex.value = _readerConfig.readerBgColorIndex.value;
    brightness.value = _prefs.getInt(_keyBrightness) ?? 80;
    useSystemBrightness.value = _prefs.getBool(_keyUseSystemBrightness) ?? true;
    lowBatteryDim.value = _prefs.getBool(_keyLowBatteryDim) ?? false;
    amoledMode.value = _prefs.getBool(_keyAmoledMode) ?? false;
    reduceWhitePoint.value = _prefs.getBool(_keyReduceWhitePoint) ?? false;
  }

  static const _keyBrightness = 'theme.brightness';
  static const _keyUseSystemBrightness = 'theme.use_system_brightness';
  static const _keyLowBatteryDim = 'theme.low_battery_dim';
  static const _keyAmoledMode = 'theme.amoled_mode';
  static const _keyReduceWhitePoint = 'theme.reduce_white_point';

  Future<void> setThemeType(AppThemeType type) async {
    themeType.value = type;
    if (amoledMode.value && type == AppThemeType.dark) {
      await _themeManager.setThemeType(AppThemeType.pureDark);
    } else {
      await _themeManager.setThemeType(type);
    }
  }

  Future<void> setReaderBgColorIndex(int index) async {
    readerBgColorIndex.value = index;
    await _readerConfig.setReaderBgColorIndex(index);
  }

  Future<void> setBrightness(int value) async {
    brightness.value = value.clamp(30, 100);
    await _prefs.setInt(_keyBrightness, brightness.value);
  }

  Future<void> setUseSystemBrightness(bool value) async {
    useSystemBrightness.value = value;
    await _prefs.setBool(_keyUseSystemBrightness, value);
  }

  Future<void> setLowBatteryDim(bool value) async {
    lowBatteryDim.value = value;
    await _prefs.setBool(_keyLowBatteryDim, value);
  }

  Future<void> setAmoledMode(bool value) async {
    amoledMode.value = value;
    await _prefs.setBool(_keyAmoledMode, value);
    if (themeType.value == AppThemeType.dark) {
      await _themeManager.setThemeType(AppThemeType.pureDark);
    }
  }

  Future<void> setReduceWhitePoint(bool value) async {
    reduceWhitePoint.value = value;
    await _prefs.setBool(_keyReduceWhitePoint, value);
  }
}
