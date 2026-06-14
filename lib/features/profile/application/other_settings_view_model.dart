import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';

@injectable
/// 其他设置 ViewModel。
///
/// 管理通知、学习目标等杂项设置的持久化状态。
class OtherSettingsViewModel {
  final SharedPreferences _prefs;

  late final notificationsEnabled = persisted<bool>(
    _prefs,
    SettingsKeys.otherNotifications,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
  );
  late final startupCheckEnabled = persisted<bool>(
    _prefs,
    SettingsKeys.otherStartupCheck,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
  );
  late final markdownPreview = persisted<bool>(
    _prefs,
    SettingsKeys.otherMarkdownPreview,
    false,
    reader: (p, k) => p.getBool(k) ?? false,
    writer: (p, k, v) => p.setBool(k, v),
  );

  bool _initialized = false;

  OtherSettingsViewModel(this._prefs);

  /// 初始化 ViewModel，读取当前语言环境和应用版本号。
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// 将所有设置恢复为默认值。
  Future<void> resetAllSettings() async {
    getIt<ReaderConfig>().resetToDefault();
    notificationsEnabled.value = true;
    startupCheckEnabled.value = true;
    markdownPreview.value = false;

    // 重置语言到跟随系统
    final tm = ThemeManager.instance;
    tm.locale.value = null;

    // 重置主题到跟随系统
    tm.themeType.value = AppThemeType.system;

    // 重置自定义颜色
    tm.customPrimaryColor.value = null;
  }

  /// 清除所有本地缓存数据。
  Future<void> clearAllLocalData() async {
    await SystemCache.clearCache();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    notificationsEnabled.dispose();
    startupCheckEnabled.dispose();
    markdownPreview.dispose();
  }
}
