import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// TTS 设置 ViewModel
///
/// 使用 [persisted] 管理 TTS 所有设置项，
/// 赋值时自动持久化到 PreferencesService（带 debounce），无需手动 _save。
class TtsSettingsViewModel {
  final PreferencesService _prefs;

  TtsSettingsViewModel(this._prefs);

  // ==================== 播放参数 ====================

  /// 语速 (0.5–2.0)
  late final speed = persistedDouble(_prefs, SettingsKeys.ttsSpeed, 1.0);

  /// 音调 (0.5–2.0)
  late final pitch = persistedDouble(_prefs, SettingsKeys.ttsPitch, 1.0);

  /// Converts the settings supported by Readium's native TTS bridge.
  ///
  /// The remaining app-level settings are intentionally not encoded here:
  /// [TTSPreferences] has no corresponding fields for them.
  TTSPreferences toReadiumPreferences() =>
      TTSPreferences(speed: speed.value, pitch: pitch.value);

  /// 释放所有 signal 资源。
  void dispose() {
    speed.dispose();
    pitch.dispose();
  }
}
