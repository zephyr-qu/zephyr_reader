import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';

@injectable
/// 主题与亮度设置 ViewModel。
///
/// 管理主题类型、阅读器背景色、亮度遮罩等设置的状态和持久化。
class ThemeBrightnessViewModel {
  final PreferencesService _prefs;
  final _themeManager = ThemeManager.instance;
  final _readerConfig = getIt<ReaderConfig>();

  late final brightness = persistedInt(_prefs, SettingsKeys.brightness, 80);
  late final useSystemBrightness = persistedBool(
    _prefs,
    SettingsKeys.useSystemBrightness,
    true,
  );

  ThemeBrightnessViewModel(this._prefs);

  /// 切换主题类型（light/dark/system）。
  Future<void> setThemeType(AppThemeType type) async {
    _themeManager.themeType.value = type;
  }

  /// 设置阅读器背景色索引。
  Future<void> setReaderBgColorIndex(int index) async {
    _readerConfig.readerBgColorIndex.value = index;
  }

  /// 设置屏幕亮度值（30–100 范围）。
  Future<void> setBrightness(int value) async {
    brightness.value = value.clamp(30, 100);
  }

  /// 切换是否跟随系统亮度。
  Future<void> setUseSystemBrightness(bool value) async {
    useSystemBrightness.value = value;
  }

  /// 释放所有 signal 资源。
  void dispose() {
    brightness.dispose();
    useSystemBrightness.dispose();
  }
}
