import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';

@injectable
class OtherSettingsViewModel {
  final SharedPreferences _prefs;

  late final notificationsEnabled = persistedBool(
    _prefs, SettingsKeys.otherNotifications, true,
  );
  late final startupCheckEnabled = persistedBool(
    _prefs, SettingsKeys.otherStartupCheck, true,
  );
  late final markdownPreview = persistedBool(
    _prefs, SettingsKeys.otherMarkdownPreview, false,
  );

  final localeCode = signal<String?>(null);
  final localeLabel = signal<String>('简体中文');
  final appVersion = signal<String>('');

  bool _initialized = false;

  OtherSettingsViewModel(this._prefs);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final tm = ThemeManager.instance;
    localeCode.value = tm.locale.value;
    localeLabel.value = tm.locale.value == 'en' ? 'English' : '简体中文';

    try {
      final info = await PackageInfo.fromPlatform();
      appVersion.value = 'v${info.version} (Build ${info.buildNumber})';
    } catch (_) {
      appVersion.value = '';
    }
  }

  Future<void> resetAllSettings() async {
    await getIt<ReaderConfig>().resetToDefault();
    notificationsEnabled.value = true;
    startupCheckEnabled.value = true;
    markdownPreview.value = false;
  }

  Future<void> clearAllLocalData() async {
    await CacheUtils.clearCache();
  }
}
