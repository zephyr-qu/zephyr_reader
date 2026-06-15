import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'preferences_service.dart';

class SharedPreferencesService implements PreferencesService {
  final SharedPreferences _prefs;

  // 缓存 Signal 实例，避免重复创建导致内存泄漏或状态不一致
  final Map<String, Signal> _signalCache = {};

  SharedPreferencesService(this._prefs);

  /// 工厂构造函数，处理异步初始化
  static Future<SharedPreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesService(prefs);
  }

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
    _notifySignal(key, value);
  }

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
    _notifySignal(key, value);
  }

  @override
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  @override
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
    _notifySignal(key, value);
  }

  @override
  int getInt(String key, {int defaultValue = 0}) =>
      _prefs.getInt(key) ?? defaultValue;

  @override
  int? getIntOrNull(String key) => _prefs.getInt(key);

  @override
  Future<void> setDouble(String key, double value) async {
    await _prefs.setDouble(key, value);
    _notifySignal(key, value);
  }

  @override
  double getDouble(String key, {double defaultValue = 0.0}) =>
      _prefs.getDouble(key) ?? defaultValue;

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
    _notifySignal(key, null);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
    _signalCache.clear(); // 清空缓存的信号
  }

  @override
  bool containsKey(String key) => _prefs.containsKey(key);

  // --- Signal 集成逻辑 ---

  @override
  Signal<String?> stringSignal(String key) {
    return _getOrCreateSignal<String?>(key, () => getString(key));
  }

  @override
  Signal<bool> boolSignal(String key, {bool defaultValue = false}) {
    return _getOrCreateSignal<bool>(
      key,
      () => getBool(key, defaultValue: defaultValue),
    );
  }

  @override
  Signal<int> intSignal(String key, {int defaultValue = 0}) {
    return _getOrCreateSignal<int>(
      key,
      () => getInt(key, defaultValue: defaultValue),
    );
  }

  /// 通用 Signal 获取/创建逻辑
  Signal<T> _getOrCreateSignal<T>(String key, T Function() initialValueGetter) {
    if (_signalCache.containsKey(key)) {
      return _signalCache[key] as Signal<T>;
    }

    final signal = Signal<T>(initialValueGetter());
    _signalCache[key] = signal;
    return signal;
  }

  /// 当值改变时，更新对应的 Signal
  void _notifySignal<T>(String key, T? newValue) {
    if (_signalCache.containsKey(key)) {
      final signal = _signalCache[key] as Signal<T?>;
      signal.value = newValue;
    }
  }
}
