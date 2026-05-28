import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';

class OtherSettingsViewModel {
  late final SharedPreferences _prefs;

  final notificationsEnabled = signal<bool>(true);
  final startupCheckEnabled = signal<bool>(true);
  final markdownPreview = signal<bool>(false);
  final customCss = signal<bool>(false);
  final advancedSearch = signal<bool>(false);

  final localeCode = signal<String?>(null);
  final localeLabel = signal<String>('简体中文');
  final appVersion = signal<String>('');

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = getIt<SharedPreferences>();

    notificationsEnabled.value = _prefs.getBool(_keyNotifications) ?? true;
    startupCheckEnabled.value = _prefs.getBool(_keyStartupCheck) ?? true;
    markdownPreview.value = _prefs.getBool(_keyMarkdownPreview) ?? false;
    customCss.value = _prefs.getBool(_keyCustomCss) ?? false;
    advancedSearch.value = _prefs.getBool(_keyAdvancedSearch) ?? false;

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

  static const _keyNotifications = 'other.notifications';
  static const _keyStartupCheck = 'other.startup_check';
  static const _keyMarkdownPreview = 'feature.markdown_preview';
  static const _keyCustomCss = 'feature.custom_css';
  static const _keyAdvancedSearch = 'feature.advanced_search';

  Future<void> setNotifications(bool value) async {
    notificationsEnabled.value = value;
    await _prefs.setBool(_keyNotifications, value);
  }

  Future<void> setStartupCheck(bool value) async {
    startupCheckEnabled.value = value;
    await _prefs.setBool(_keyStartupCheck, value);
  }

  Future<void> setMarkdownPreview(bool value) async {
    markdownPreview.value = value;
    await _prefs.setBool(_keyMarkdownPreview, value);
  }

  Future<void> setCustomCss(bool value) async {
    customCss.value = value;
    await _prefs.setBool(_keyCustomCss, value);
  }

  Future<void> setAdvancedSearch(bool value) async {
    advancedSearch.value = value;
    await _prefs.setBool(_keyAdvancedSearch, value);
  }

  Future<void> resetAllSettings() async {
    final config = getIt<ReaderConfig>();
    await config.resetToDefault();
    await setNotifications(true);
    await setStartupCheck(true);
    await setMarkdownPreview(false);
    await setCustomCss(false);
    await setAdvancedSearch(false);
  }

  Future<void> clearAllLocalData() async {
    await CacheUtils.clearCache();
  }
}
