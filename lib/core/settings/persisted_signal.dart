import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

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

  /// 当前值
  T get value => _signal.value;

  /// 设置当前值并调度持久化
  set value(T v) {
    _signal.value = v;
    _scheduleSave();
  }

  PersistedSignal._({
    required T initialValue,
    required this.key,
    required SharedPreferences prefs,
    required Future<void> Function(SharedPreferences, String, T) write,
    Duration debounce = const Duration(milliseconds: 150),
  }) : _signal = Signal<T>(initialValue),
       _prefs = prefs,
       _write = write,
       _debounce = debounce;

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
    await _write(_prefs, key, _signal.value);
  }

  /// 立即写入，跳过 debounce
  Future<void> saveImmediately() async {
    _saveTimer?.cancel();
    await _write(_prefs, key, _signal.value);
  }

  /// 关联信号原值（用于 `useSignal`、`SignalBuilder` 等）
  Signal<T> get signal => _signal;

  /// 取消待写入的 timer。不再使用此信号时调用
  void dispose() {
    _saveTimer?.cancel();
  }
}

// ==================== 类型工厂 ====================

/// [bool] 类型持久化信号
PersistedSignal<bool> persistedBool(
  SharedPreferences prefs,
  String key,
  bool defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<bool>._(
    initialValue: prefs.getBool(key) ?? defaultValue,
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setBool(k, v),
    debounce: debounce,
  );
}

/// [int] 类型持久化信号
PersistedSignal<int> persistedInt(
  SharedPreferences prefs,
  String key,
  int defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<int>._(
    initialValue: prefs.getInt(key) ?? defaultValue,
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setInt(k, v),
    debounce: debounce,
  );
}

/// [double] 类型持久化信号
PersistedSignal<double> persistedDouble(
  SharedPreferences prefs,
  String key,
  double defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<double>._(
    initialValue: prefs.getDouble(key) ?? defaultValue,
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setDouble(k, v),
    debounce: debounce,
  );
}

/// [String] 类型持久化信号
PersistedSignal<String> persistedString(
  SharedPreferences prefs,
  String key,
  String defaultValue, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<String>._(
    initialValue: prefs.getString(key) ?? defaultValue,
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setString(k, v),
    debounce: debounce,
  );
}

/// 可为 null 的 [String] 类型持久化信号。
/// 值为 null 时从 SharedPreferences 中删除该键。
PersistedSignal<String?> persistedNullableString(
  SharedPreferences prefs,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<String?>._(
    initialValue: prefs.getString(key),
    key: key,
    prefs: prefs,
    write: (p, k, v) {
      if (v != null) {
        return p.setString(k, v);
      } else {
        return p.remove(k);
      }
    },
    debounce: debounce,
  );
}

/// 可为 null 的 [int] 类型持久化信号（用于存储 [Color] 的 ARGB32 值）。
/// 值为 null 时从 SharedPreferences 中删除该键。
PersistedSignal<int?> persistedNullableInt(
  SharedPreferences prefs,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<int?>._(
    initialValue: prefs.getInt(key),
    key: key,
    prefs: prefs,
    write: (p, k, v) {
      if (v != null) {
        return p.setInt(k, v);
      } else {
        return p.remove(k);
      }
    },
    debounce: debounce,
  );
}

/// [Enum] 类型持久化信号（通过字符串 ID 持久化）
PersistedSignal<T> persistedEnum<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  T Function(String) parser, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<T>._(
    initialValue: _readEnum(prefs, key, defaultValue, parser),
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setString(k, v.name),
    debounce: debounce,
  );
}

/// [Enum] 类型持久化信号（使用自定义序列化器，如 [BookshelfSortType.key]）
PersistedSignal<T> persistedEnumCustom<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  T Function(String) parser,
  String Function(T) serializer, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<T>._(
    initialValue: _readEnum(prefs, key, defaultValue, parser),
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setString(k, serializer(v)),
    debounce: debounce,
  );
}

T _readEnum<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  T Function(String) parser,
) {
  final stored = prefs.getString(key);
  if (stored == null) return defaultValue;
  try {
    return parser(stored);
  } catch (_) {
    return defaultValue;
  }
}

/// [Color] 类型持久化信号（以 ARGB32 int 存储）
PersistedSignal<Color?> persistedColor(
  SharedPreferences prefs,
  String key, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<Color?>._(
    initialValue: _readColor(prefs, key),
    key: key,
    prefs: prefs,
    write: (p, k, v) {
      if (v != null) {
        return p.setInt(k, v.toARGB32());
      } else {
        return p.remove(k);
      }
    },
    debounce: debounce,
  );
}

Color? _readColor(SharedPreferences prefs, String key) {
  final value = prefs.getInt(key);
  if (value == null) return null;
  return Color(value);
}

/// [AppThemeType]-like 枚举持久化（通过 index 存储）
PersistedSignal<T> persistedEnumByIndex<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  List<T> values, {
  Duration debounce = const Duration(milliseconds: 150),
}) {
  return PersistedSignal<T>._(
    initialValue: _readEnumByIndex(prefs, key, defaultValue, values),
    key: key,
    prefs: prefs,
    write: (p, k, v) => p.setInt(k, v.index),
    debounce: debounce,
  );
}

T _readEnumByIndex<T extends Enum>(
  SharedPreferences prefs,
  String key,
  T defaultValue,
  List<T> values,
) {
  final index = prefs.getInt(key);
  if (index == null || index < 0 || index >= values.length) return defaultValue;
  return values[index];
}
