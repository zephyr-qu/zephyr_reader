

import 'package:signals_flutter/signals_flutter.dart';

abstract class PreferencesService {
  // 基础读写
  Future<void> setString(String key, String value);
  String? getString(String key);
  
  Future<void> setBool(String key, bool value);
  bool getBool(String key, {bool defaultValue = false});

  Future<void> setInt(String key, int value);
  int getInt(String key, {int defaultValue = 0});

  Future<void> setDouble(String key, double value);
  double getDouble(String key, {double defaultValue = 0.0});

  /// 获取可空整型值（区分"键不存在"和值为 0）
  int? getIntOrNull(String key);


  /// 检查键是否存在
  bool containsKey(String key);
  Future<void> remove(String key);
  Future<void> clear();

  // 信号化读取 (UI 层专用)
  Signal<String?> stringSignal(String key);
  Signal<bool> boolSignal(String key, {bool defaultValue = false});
  Signal<int> intSignal(String key, {int defaultValue = 0});
}
