/// 自动主题切换服务
///
/// 根据日落日出时间自动切换亮色/深色主题
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 自动主题切换服务
class AutoThemeService {
  final SharedPreferences _prefs;

  /// 是否启用自动主题切换
  final autoThemeEnabled = signal(false);

  /// 深色模式开始时间（小时�?
  final darkModeStartHour = signal(18);

  /// 深色模式结束时间（小时）
  final darkModeEndHour = signal(6);

  /// 当前主题模式
  final themeMode = signal<ThemeMode>(ThemeMode.system);

  AutoThemeService(this._prefs) {
    _loadSettings();
    _startAutoSwitch();
  }

  static const String _keyAutoTheme = 'auto_theme_enabled';
  static const String _keyDarkModeStart = 'dark_mode_start_hour';
  static const String _keyDarkModeEnd = 'dark_mode_end_hour';

  /// 加载设置
  Future<void> _loadSettings() async {
    autoThemeEnabled.value = _prefs.getBool(_keyAutoTheme) ?? false;
    darkModeStartHour.value = _prefs.getInt(_keyDarkModeStart) ?? 18;
    darkModeEndHour.value = _prefs.getInt(_keyDarkModeEnd) ?? 6;
    _updateThemeMode();
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    await _prefs.setBool(_keyAutoTheme, autoThemeEnabled.value);
    await _prefs.setInt(_keyDarkModeStart, darkModeStartHour.value);
    await _prefs.setInt(_keyDarkModeEnd, darkModeEndHour.value);
  }

  /// 启用自动主题切换
  Future<void> enableAutoTheme() async {
    autoThemeEnabled.value = true;
    await _saveSettings();
    _updateThemeMode();
  }

  /// 禁用自动主题切换
  Future<void> disableAutoTheme() async {
    autoThemeEnabled.value = false;
    await _saveSettings();
    themeMode.value = ThemeMode.system;
  }

  /// 设置深色模式时间
  Future<void> setDarkModeTime(int startHour, int endHour) async {
    darkModeStartHour.value = startHour;
    darkModeEndHour.value = endHour;
    await _saveSettings();
    _updateThemeMode();
  }

  /// 更新主题模式
  void _updateThemeMode() {
    if (!autoThemeEnabled.value) {
      return;
    }

    final now = DateTime.now();
    final currentHour = now.hour;
    final startHour = darkModeStartHour.value;
    final endHour = darkModeEndHour.value;

    bool isDarkMode;
    if (startHour > endHour) {
      // 跨天情况（如 18 �?- 6 点）
      isDarkMode = currentHour >= startHour || currentHour < endHour;
    } else {
      // 不跨天情况（�?20 �?- 4 点）
      isDarkMode = currentHour >= startHour && currentHour < endHour;
    }

    themeMode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    debugPrint('自动主题切换�?{isDarkMode ? "深色" : "浅色"} 模式');
  }

  /// 开始自动切�?
  void _startAutoSwitch() {
    // 每小时检查一�?
    Future.delayed(const Duration(hours: 1), () {
      _updateThemeMode();
      _startAutoSwitch();
    });
  }

  /// 获取日出时间（估算）
  Duration getSunriseTime() {
    return Duration(hours: darkModeEndHour.value);
  }

  /// 获取日落时间（估算）
  Duration getSunsetTime() {
    return Duration(hours: darkModeStartHour.value);
  }

  /// 是否为深色模式时�?
  bool get isDarkModeTime {
    if (!autoThemeEnabled.value) {
      return false;
    }

    final now = DateTime.now();
    final currentHour = now.hour;
    final startHour = darkModeStartHour.value;
    final endHour = darkModeEndHour.value;

    if (startHour > endHour) {
      return currentHour >= startHour || currentHour < endHour;
    } else {
      return currentHour >= startHour && currentHour < endHour;
    }
  }
}

/// 主题时间预设
enum ThemeTimePreset {
  /// 日落到日�?
  sunsetToSunrise('日落到日出', 18, 6),

  /// 傍晚到早�?
  eveningToMorning('傍晚到早晨', 20, 7),

  /// 自定�?
  custom('自定义', 0, 0);

  final String displayName;
  final int startHour;
  final int endHour;

  const ThemeTimePreset(this.displayName, this.startHour, this.endHour);

  static ThemeTimePreset fromHours(int start, int end) {
    for (final preset in values) {
      if (preset.startHour == start && preset.endHour == end) {
        return preset;
      }
    }
    return ThemeTimePreset.custom;
  }
}
