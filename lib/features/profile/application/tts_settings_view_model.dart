import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// TTS 设置 ViewModel
///
/// 使用 [persisted] 管理 TTS 所有设置项，
/// 赋值时自动持久化到 PreferencesService（带 debounce），无需手动 _save。
@injectable
class TtsSettingsViewModel {
  final PreferencesService _prefs;

  TtsSettingsViewModel(this._prefs);

  // ==================== 播放参数 ====================

  /// 语速 (0.5–2.0)
  late final speed = persistedDouble(_prefs, SettingsKeys.ttsSpeed, 1.0);

  /// 音调 (0.5–2.0)
  late final pitch = persistedDouble(_prefs, SettingsKeys.ttsPitch, 1.0);

  /// 句间停顿 (ms, 0–1000)
  late final pauseBetween = persistedInt(
    _prefs,
    SettingsKeys.ttsPauseBetween,
    300,
  );

  // ==================== 双语朗读 ====================

  /// 双语交替朗读
  late final bilingualAlternate = persistedBool(
    _prefs,
    SettingsKeys.ttsBilingualAlternate,
    true,
  );

  /// 仅朗读原文
  late final originalOnly = persistedBool(
    _prefs,
    SettingsKeys.ttsOriginalOnly,
    false,
  );

  /// 中英切换间隔 (ms)
  late final switchInterval = persistedInt(
    _prefs,
    SettingsKeys.ttsSwitchInterval,
    500,
  );

  // ==================== 行为偏好 ====================

  /// 后台播放
  late final backgroundPlay = persistedBool(
    _prefs,
    SettingsKeys.ttsBackgroundPlay,
    true,
  );

  /// 自动翻页
  late final autoPage = persistedBool(_prefs, SettingsKeys.ttsAutoPage, true);

  /// 高亮跟随
  late final highlightFollow = persistedBool(
    _prefs,
    SettingsKeys.ttsHighlightFollow,
    true,
  );

  /// 息屏时降低音量
  late final dimOnLock = persistedBool(
    _prefs,
    SettingsKeys.ttsDimOnLock,
    false,
  );

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
    pauseBetween.dispose();
    bilingualAlternate.dispose();
    originalOnly.dispose();
    switchInterval.dispose();
    backgroundPlay.dispose();
    autoPage.dispose();
    highlightFollow.dispose();
    dimOnLock.dispose();
  }
}
