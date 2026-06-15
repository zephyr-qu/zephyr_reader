import 'dart:async';

import 'dart:ui' show Color;
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 自持久化信号量
///
/// 将 [Signal] 与 [PreferencesService] 读写绑定，赋值时自动触发带 debounce 的持久化。
/// 构造时从 [PreferencesService] 读取初始值，无需手动 `_loadSettings`。
///
/// 使用 [dispose] 取消待写入的 timer。
class PersistedSignal<T> {
  final Signal<T> _signal;
  final String key;
  final PreferencesService _service;
  Timer? _saveTimer;
  final Duration _debounce;
  final Future<void> Function(PreferencesService, String, T) _write;
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
    required this._service,
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
      await _write(_service, key, _signal.value);
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
///   service, SettingsKeys.readerAutoScroll, false,
///   reader: (s, k) => s.getBool(k, defaultValue: false),
///   writer: (s, k, v) => s.setBool(k, v),
/// );
/// ```
PersistedSignal<T> persisted<T>(
  PreferencesService service,
  String key,
  T defaultValue, {
  required T Function(PreferencesService, String) reader,
  required Future<void> Function(PreferencesService, String, T) writer,
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<T>._(
    initialValue: reader(service, key),
    defaultValue: defaultValue,
    key: key,
    service: service,
    write: writer,
    debounce: debounce,
  );
}

// ==================== 便捷工厂（避免 reader/writer 模板代码） ====================

/// [bool] 类型的 [PersistedSignal] 工厂。
PersistedSignal<bool> persistedBool(
  PreferencesService service,
  String key,
  bool defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<bool>(
    service,
    key,
    defaultValue,
    reader: (s, k) => s.getBool(k, defaultValue: defaultValue),
    writer: (s, k, v) => s.setBool(k, v),
    debounce: debounce,
  );
}

/// [int] 类型的 [PersistedSignal] 工厂。
PersistedSignal<int> persistedInt(
  PreferencesService service,
  String key,
  int defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<int>(
    service,
    key,
    defaultValue,
    reader: (s, k) => s.getInt(k, defaultValue: defaultValue),
    writer: (s, k, v) => s.setInt(k, v),
    debounce: debounce,
  );
}

/// [double] 类型的 [PersistedSignal] 工厂。
PersistedSignal<double> persistedDouble(
  PreferencesService service,
  String key,
  double defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<double>(
    service,
    key,
    defaultValue,
    reader: (s, k) => s.getDouble(k, defaultValue: defaultValue),
    writer: (s, k, v) => s.setDouble(k, v),
    debounce: debounce,
  );
}

/// [String] 类型的 [PersistedSignal] 工厂。
PersistedSignal<String> persistedString(
  PreferencesService service,
  String key,
  String defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<String>(
    service,
    key,
    defaultValue,
    reader: (s, k) => s.getString(k) ?? defaultValue,
    writer: (s, k, v) => s.setString(k, v),
    debounce: debounce,
  );
}

/// 可空 [String?] 类型的 [PersistedSignal] 工厂。
///
/// 写入 `null` 时从 PreferencesService 移除该键。
PersistedSignal<String?> persistedNullableString(
  PreferencesService service,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<String?>(
    service,
    key,
    null,
    reader: (s, k) => s.getString(k),
    writer: (s, k, v) => v != null ? s.setString(k, v) : s.remove(k),
    debounce: debounce,
  );
}

/// 可空 [int?] 类型的 [PersistedSignal] 工厂。
///
/// 写入 `null` 时从 PreferencesService 移除该键。
PersistedSignal<int?> persistedNullableInt(
  PreferencesService service,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<int?>(
    service,
    key,
    null,
    reader: (s, k) => s.getIntOrNull(k),
    writer: (s, k, v) => v != null ? s.setInt(k, v) : s.remove(k),
    debounce: debounce,
  );
}

/// 枚举类型的 [PersistedSignal] 工厂（字符串序列化）。
///
/// 使用 [parser] 从字符串反序列化枚举值，使用 [name] 序列化。
PersistedSignal<T> persistedEnum<T extends Enum>(
  PreferencesService service,
  String key,
  T defaultValue,
  T Function(String) parser, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<T>(
    service,
    key,
    defaultValue,
    reader: (s, k) => readEnum(s, k, defaultValue, parser),
    writer: (s, k, v) => s.setString(k, v.name),
    debounce: debounce,
  );
}

/// 枚举类型的 [PersistedSignal] 工厂（自定义序列化）。
///
/// 使用 [reader] 从字符串反序列化，使用 [writer] 自定义序列化。
PersistedSignal<T> persistedEnumCustom<T extends Enum>(
  PreferencesService service,
  String key,
  T defaultValue,
  T Function(String) reader,
  String Function(T) writer, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<T>(
    service,
    key,
    defaultValue,
    reader: (s, k) {
      final stored = s.getString(k);
      if (stored == null) return defaultValue;
      try {
        return reader(stored);
      } catch (_) {}
      return defaultValue;
    },
    writer: (s, k, v) => s.setString(k, writer(v)),
    debounce: debounce,
  );
}

/// [Color?] 类型的 [PersistedSignal] 工厂（ARGB32 int 存储）。
///
/// 写入 `null` 时从 PreferencesService 移除该键。
PersistedSignal<Color?> persistedColor(
  PreferencesService service,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return persisted<Color?>(
    service,
    key,
    null,
    reader: (s, k) => readColor(s, k),
    writer: (s, k, v) => v != null ? s.setInt(k, v.toARGB32()) : s.remove(k),
    debounce: debounce,
  );
}

// ==================== 枚举/颜色读取辅助 ====================

/// 从 [PreferencesService] 读取枚举值，解析失败时返回 [defaultValue]。
T readEnum<T extends Enum>(
  PreferencesService service,
  String key,
  T defaultValue,
  T Function(String) parser,
) {
  final stored = service.getString(key);
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

/// 从 [PreferencesService] 读取 [Color] 值（以 ARGB32 int 存储）。
Color? readColor(PreferencesService service, String key) {
  final value = service.getIntOrNull(key);
  if (value == null) return null;
  return Color(value);
}
