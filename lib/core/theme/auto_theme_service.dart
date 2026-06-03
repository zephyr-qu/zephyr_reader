/// 自动主题切换服务
///
/// 根据日落日出时间自动切换亮色/深色主题
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../settings/persisted_signal.dart';
import '../settings/settings_keys.dart';
import '../utils/logging.dart';
class AutoThemeService {
  final SharedPreferences _prefs;
  Timer? _autoSwitchTimer;

  /// 是否启用自动主题切换
  late final autoThemeEnabled = persistedBool(
    _prefs, SettingsKeys.autoThemeEnabled, false,
  );

  /// 深色模式开始时间（小时）
  late final darkModeStartHour = persistedInt(
    _prefs, SettingsKeys.darkModeStartHour, 18,
  );

  /// 深色模式结束时间（小时）
  late final darkModeEndHour = persistedInt(
    _prefs, SettingsKeys.darkModeEndHour, 6,
  );

  /// 当前主题模式
  final themeMode = signal<ThemeMode>(ThemeMode.system);

  AutoThemeService(this._prefs) {
    // 初始化时根据已持久化的值更新主题模式
    _updateThemeMode();
    _startAutoSwitch();
  }

  /// 启用自动主题切换
  Future<void> enableAutoTheme() async {
    autoThemeEnabled.value = true;
    _updateThemeMode();
  }

  Future<void> disableAutoTheme() async {
    autoThemeEnabled.value = false;
    themeMode.value = ThemeMode.system;
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = null;
  }

  /// 设置深色模式时间
  Future<void> setDarkModeTime(int startHour, int endHour) async {
    darkModeStartHour.value = startHour;
    darkModeEndHour.value = endHour;
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
      // 跨天情况（如 18 - 6 点）
      isDarkMode = currentHour >= startHour || currentHour < endHour;
    } else {
      // 不跨天情况（20 - 4 点）
      isDarkMode = currentHour >= startHour && currentHour < endHour;
    }

    themeMode.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    Logging.debug('自动主题切换{isDarkMode ? "深色" : "浅色"} 模式');
  }

  /// 开始自动切换
  void _startAutoSwitch() {
    // 每小时检查一次，使用 Timer.periodic 避免递归漂移
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _updateThemeMode();
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

  /// 是否为深色模式时
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
  /// 日落到日
  sunsetToSunrise('日落到日出', 18, 6),

  /// 傍晚到早
  eveningToMorning('傍晚到早晨', 20, 7),

  /// 自定
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
