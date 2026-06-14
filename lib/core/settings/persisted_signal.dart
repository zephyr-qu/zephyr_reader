import 'dart:async';

import 'dart:ui' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 自持久化信号量
///
/// 将 [Signal] 与 [SharedPreferences] 读写绑定，赋值时自动触发带 debounce 的持久化。
/// 构造时从 [SharedPreferences] 读取初始值，无需手动 `_loadSettings`。
///
/// 使用 [dispose] 取消待写入的 timer。
class PersistedSignal<T> {
  final Signal<T> _signal;
  final String key;
  final SharedPreferences _prefs;
  Timer? _saveTimer;
  final Duration _debounce;
  final Future<void> Function(SharedPreferences, String, T) _write;
  bool _disposed = false;

  /// 默认值（用于 reset 恢复）
  final T defaultValue;

  /// 当前值
  T get value => _signal.value;

  /// 设置当前值并调度持久化
  set value(T v) {
    if (_signal.peek() == v) return;
    _signal.value = v;
    _scheduleSave();
  }

  PersistedSignal._({
    required T initialValue,
    required this.defaultValue,
    required this.key,
    required this._prefs,
    required this._write,
    this._debounce = const Duration(milliseconds: 150),
  }) : _signal = Signal<T>(initialValue);
  void _scheduleSave() {
    _saveTimer?.cancel();
    if (_debounce == Duration.zero) {
      unawaited(_save());
    } else {
      _saveTimer = Timer(_debounce, () {
        unawaited(_save());
      });
    }
  }

  Future<void> _save() async {
    if (_disposed) return;
    try {
      await _write(_prefs, key, _signal.value);
    } catch (e) {
      Logging.warning('PersistedSignal[$key] save failed: $e');
    }
  }

  /// 立即写入，跳过 debounce
  Future<void> saveImmediately() async {
    _saveTimer?.cancel();
    await _save();
  }

  /// 关联信号原值（用于 `useSignal`、`SignalBuilder` 等）
  Signal<T> get signal => _signal;

  /// 重置为默认值
  void reset() {
    value = defaultValue;
  }

  /// 取消待写入的 timer。不再使用此信号时调用
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
  }
}


// ==================== 通用工厂 ====================

/// 泛型 [PersistedSignal] 工厂。
///
/// 通过 [reader] 读取初始值，通过 [writer] 持久化新值。
/// 可用于任意类型，包括内置不支持的类型（自定义编码）。
///
/// 示例：
/// ```dart
/// persisted<bool>(
///   prefs, SettingsKeys.readerAutoScroll, false,
///   reader: (p, k) => p.getBool(k) ?? false,
///   writer: (p, k, v) => p.setBool(k, v),
/// );
/// ```
PersistedSignal<T> persisted<T>(
  SharedPreferences prefs,
  String key,
  T defaultValue, {
  required T Function(SharedPreferences, String) reader,
  required Future<void> Function(SharedPreferences, String, T) writer,
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<T>._(
    initialValue: reader(prefs, key),
    defaultValue: defaultValue,
    key: key,
    prefs: prefs,
    write: writer,
    debounce: debounce,
  );
}

// ==================== 枚举/颜色读取辅助 ====================

/// 从 [SharedPreferences] 读取枚举值，解析失败时返回 [defaultValue]。
T readEnum<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  T Function(String) parser,
) {
  final stored = prefs.getString(key);
  if (stored == null) return defaultValue;
  try {
    return parser(stored);
  } catch (e) {
    Logging.warning(
      'PersistedSignal.readEnum[$key] failed to parse "$stored": $e',
    );
    return defaultValue;
  }
}

/// 从 [SharedPreferences] 读取 [Color] 值（以 ARGB32 int 存储）。
Color? readColor(SharedPreferences prefs, String key) {
  final value = prefs.getInt(key);
  if (value == null) return null;
  return Color(value);
}
