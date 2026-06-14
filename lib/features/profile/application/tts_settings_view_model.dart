import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// TTS 设置 ViewModel
///
/// 使用 [persisted]<T> 管理 TTS 所有设置项，
/// 赋值时自动持久化到 SharedPreferences（带 debounce），无需手动 _save。
@injectable
class TtsSettingsViewModel {
  final SharedPreferences _prefs;

  TtsSettingsViewModel(this._prefs);

  // ==================== 播放参数 ====================

  /// 语速 (0.5–2.0)
  late final speed = persisted<double>(_prefs, SettingsKeys.ttsSpeed, 1.0, reader: (p, k) => p.getDouble(k) ?? 1.0, writer: (p, k, v) => p.setDouble(k, v));

  /// 音调 (0.5–2.0)
  late final pitch = persisted<double>(_prefs, SettingsKeys.ttsPitch, 1.0, reader: (p, k) => p.getDouble(k) ?? 1.0, writer: (p, k, v) => p.setDouble(k, v));

  /// 句间停顿 (ms, 0–1000)
  late final pauseBetween = persisted<int>(
    _prefs,
    SettingsKeys.ttsPauseBetween,
    300,
    reader: (p, k) => p.getInt(k) ?? 300,
    writer: (p, k, v) => p.setInt(k, v),
  );

  // ==================== 双语朗读 ====================

  /// 双语交替朗读
  late final bilingualAlternate = persisted<bool>(
    _prefs,
    SettingsKeys.ttsBilingualAlternate,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
  );

  /// 仅朗读原文
  late final originalOnly = persisted<bool>(
    _prefs,
    SettingsKeys.ttsOriginalOnly,
    false,
    reader: (p, k) => p.getBool(k) ?? false,
    writer: (p, k, v) => p.setBool(k, v),
  );

  /// 中英切换间隔 (ms)
  late final switchInterval = persisted<int>(
    _prefs,
    SettingsKeys.ttsSwitchInterval,
    500,
    reader: (p, k) => p.getInt(k) ?? 500,
    writer: (p, k, v) => p.setInt(k, v),
  );

  // ==================== 行为偏好 ====================

  /// 后台播放
  late final backgroundPlay = persisted<bool>(
    _prefs,
    SettingsKeys.ttsBackgroundPlay,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
  );

  /// 自动翻页
  late final autoPage = persisted<bool>(_prefs, SettingsKeys.ttsAutoPage, true, reader: (p, k) => p.getBool(k) ?? true, writer: (p, k, v) => p.setBool(k, v));

  /// 高亮跟随
  late final highlightFollow = persisted<bool>(
    _prefs,
    SettingsKeys.ttsHighlightFollow,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
  );

  /// 息屏时降低音量
  late final dimOnLock = persisted<bool>(
    _prefs,
    SettingsKeys.ttsDimOnLock,
    false,
    reader: (p, k) => p.getBool(k) ?? false,
    writer: (p, k, v) => p.setBool(k, v),
  );

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
