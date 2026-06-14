import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// 翻译 API 配置。
///
/// 管理所有翻译 API 相关的可持久化设置。
/// 使用 [PersistedSignal] 实现自动保存到 SharedPreferences。
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

  TranslationConfig(SharedPreferences prefs) :
      provider = persisted<String>(
        prefs,
        SettingsKeys.translationProvider,
        'openai',
        reader: (p, k) => p.getString(k) ?? 'openai',
        writer: (p, k, v) => p.setString(k, v),
      ),
      apiUrl = persisted<String>(
        prefs,
        SettingsKeys.translationApiUrl,
        'https://api.openai.com',
        reader: (p, k) => p.getString(k) ?? 'https://api.openai.com',
        writer: (p, k, v) => p.setString(k, v),
      ),
      apiKey = persisted<String>(
        prefs,
        SettingsKeys.translationApiKey,
        '',
        reader: (p, k) => p.getString(k) ?? '',
        writer: (p, k, v) => p.setString(k, v),
      ),
      model = persisted<String>(
        prefs,
        SettingsKeys.translationModel,
        'gpt-4o-mini',
        reader: (p, k) => p.getString(k) ?? 'gpt-4o-mini',
        writer: (p, k, v) => p.setString(k, v),
      ),
      targetLang = persisted<String>(
        prefs,
        SettingsKeys.translationTargetLang,
        'zh',
        reader: (p, k) => p.getString(k) ?? 'zh',
        writer: (p, k, v) => p.setString(k, v),
      ),
      sourceLang = persisted<String>(
        prefs,
        SettingsKeys.translationSourceLang,
        'auto',
        reader: (p, k) => p.getString(k) ?? 'auto',
        writer: (p, k, v) => p.setString(k, v),
      ),
      timeoutSeconds = persisted<int>(prefs, SettingsKeys.translationTimeout, 30,
        reader: (p, k) => p.getInt(k) ?? 30,
        writer: (p, k, v) => p.setInt(k, v),
      );

  /// 是否已配置（API URL 和 Key 均非空）。
  bool get isConfigured => apiUrl.value.isNotEmpty && apiKey.value.isNotEmpty;
}
