import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// 翻译 API 配置。
///
/// 管理所有翻译 API 相关的可持久化设置。
/// 使用 [PersistedSignal] 实现自动保存到 PreferencesService。
@singleton
class TranslationConfig {
  /// 服务提供商
  final PersistedSignal<String> provider;

  /// API 端点地址
  final PersistedSignal<String> apiUrl;

  /// API 密钥
  final PersistedSignal<String> apiKey;

  /// 模型名（仅 OpenAI）
  final PersistedSignal<String> model;

  /// 目标语言代码
  final PersistedSignal<String> targetLang;

  /// 源语言代码（"auto" 表示自动检测）
  final PersistedSignal<String> sourceLang;

  /// 请求超时秒数
  final PersistedSignal<int> timeoutSeconds;

  TranslationConfig(PreferencesService prefs)
    : provider = persistedString(
        prefs,
        SettingsKeys.translationProvider,
        'openai',
      ),
      apiUrl = persistedString(
        prefs,
        SettingsKeys.translationApiUrl,
        'https://api.openai.com',
      ),
      apiKey = persistedString(prefs, SettingsKeys.translationApiKey, ''),
      model = persistedString(
        prefs,
        SettingsKeys.translationModel,
        'gpt-4o-mini',
      ),
      targetLang = persistedString(
        prefs,
        SettingsKeys.translationTargetLang,
        'zh',
      ),
      sourceLang = persistedString(
        prefs,
        SettingsKeys.translationSourceLang,
        'auto',
      ),
      timeoutSeconds = persistedInt(prefs, SettingsKeys.translationTimeout, 30);

  /// 是否已配置（API URL 和 Key 均非空）。
  bool get isConfigured => apiUrl.value.isNotEmpty && apiKey.value.isNotEmpty;
}
