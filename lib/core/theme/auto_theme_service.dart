/// 自动主题切换服务
///
/// 根据日落日出时间自动切换亮色/深色主题。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../settings/persisted_signal.dart';
import '../settings/settings_keys.dart';
import '../utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class AutoThemeService {
  final SharedPreferences _prefs;
  Timer? _autoSwitchTimer;

  /// 是否启用自动主题切换
  late final autoThemeEnabled = persistedBool(
    _prefs,
    SettingsKeys.autoThemeEnabled,
    false,
  );

  /// 深色模式开始时间（小时）
  late final darkModeStartHour = persistedInt(
    _prefs,
    SettingsKeys.darkModeStartHour,
    18,
  );

  /// 深色模式结束时间（小时）
  late final darkModeEndHour = persistedInt(
    _prefs,
    SettingsKeys.darkModeEndHour,
    6,
  );

  /// 当前主题模式
  final themeMode = signal<ThemeMode>(ThemeMode.system);

  /// 当前小时是否在深色模式时间窗口内（支持跨天区间）
  static bool _isDarkHour(int currentHour, int startHour, int endHour) {
    if (startHour > endHour) {
      // 跨天情况（如 18–6: 当前 ≥18 或 <6）
      return currentHour >= startHour || currentHour < endHour;
    } else {
      // 不跨天情况（如 20–4: 当前 ≥20 且 <4）—— 实际不会出现，因为 endHour ≤ startHour 才进入此分支
      return currentHour >= startHour && currentHour < endHour;
    }
  }

  AutoThemeService(this._prefs) {
    // 初始化时根据已持久化的值更新主题模式
    _updateThemeMode();
    _scheduleNextCheck();
  }

  /// 启用自动主题切换
  Future<void> enableAutoTheme() async {
    autoThemeEnabled.value = true;
    _updateThemeMode();
    _scheduleNextCheck();
  }

  Future<void> disableAutoTheme() async {
    autoThemeEnabled.value = false;
    themeMode.value = ThemeMode.system;
    _autoSwitchTimer?.cancel();
    _autoSwitchTimer = null;
  }

  Future<void> setDarkModeTime(int startHour, int endHour) async {
    darkModeStartHour.value = startHour;
    darkModeEndHour.value = endHour;
    _updateThemeMode();
    _scheduleNextCheck();
  }

  /// 更新主题模式
  void _updateThemeMode() {
    if (!autoThemeEnabled.value) {
      return;
    }

    final now = DateTime.now();
    final isDark = _isDarkHour(
      now.hour,
      darkModeStartHour.value,
      darkModeEndHour.value,
    );
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    Logging.debug('自动主题切换${isDark ? "深色" : "浅色"} 模式');
  }

  /// 距离下一次主题切换的时长（精确到分钟）
  Duration _timeUntilNextTransition() {
    const dayMinutes = 24 * 60;
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = darkModeStartHour.value * 60;
    final endMinutes = darkModeEndHour.value * 60;

    if (startMinutes > endMinutes) {
      // 深色模式跨天（如 18:00→06:00）
      if (currentMinutes >= startMinutes || currentMinutes < endMinutes) {
        // 当前处于深色 → 下次切换在 endMinutes（日出）
        if (currentMinutes < endMinutes) {
          return Duration(minutes: endMinutes - currentMinutes);
        } else {
          return Duration(minutes: dayMinutes - currentMinutes + endMinutes);
        }
      } else {
        // 当前处于浅色 → 下次切换在 startMinutes（日落），同天
        return Duration(minutes: startMinutes - currentMinutes);
      }
    } else {
      // 深色模式当天（如 08:00→18:00）
      if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
        // 当前处于深色 → 下次切换在 endMinutes，同天
        return Duration(minutes: endMinutes - currentMinutes);
      } else {
        // 当前处于浅色 → 下次切换在 startMinutes
        if (currentMinutes < startMinutes) {
          return Duration(minutes: startMinutes - currentMinutes);
        } else {
          return Duration(minutes: dayMinutes - currentMinutes + startMinutes);
        }
      }
    }
  }

  /// 安排下一次精确切换（取代旧的 Timer.periodic 小时轮询）
  void _scheduleNextCheck() {
    if (!autoThemeEnabled.value) return;
    _autoSwitchTimer?.cancel();
    final duration = _timeUntilNextTransition();
    Logging.debug('距离下次主题切换还有 ${duration.inMinutes} 分钟');
    _autoSwitchTimer = Timer(duration, () {
      _updateThemeMode();
      _scheduleNextCheck();
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

  bool get isDarkModeTime {
    if (!autoThemeEnabled.value) {
      return false;
    }
    return _isDarkHour(
      DateTime.now().hour,
      darkModeStartHour.value,
      darkModeEndHour.value,
    );
  }

  /// 释放所有 signal 和 timer 资源。
  void dispose() {
    autoThemeEnabled.dispose();
    darkModeStartHour.dispose();
    darkModeEndHour.dispose();
    themeMode.dispose();
    _autoSwitchTimer?.cancel();
  }
}

/// 主题时间预设
enum ThemeTimePreset {
  /// 日落到日出（18:00–06:00）
  sunsetToSunrise(18, 6),

  /// 傍晚到早晨（20:00–07:00）
  eveningToMorning(20, 7),

  /// 自定义
  custom(0, 0);

  final int startHour;
  final int endHour;

  const ThemeTimePreset(this.startHour, this.endHour);

  static ThemeTimePreset fromHours(int start, int end) {
    for (final preset in values) {
      if (preset.startHour == start && preset.endHour == end) {
        return preset;
      }
    }
    return ThemeTimePreset.custom;
  }
}

extension ThemeTimePresetX on ThemeTimePreset {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    ThemeTimePreset.sunsetToSunrise => l10n.timePresetSunsetToSunrise,
    ThemeTimePreset.eveningToMorning => l10n.timePresetEveningToMorning,
    ThemeTimePreset.custom => l10n.timePresetCustom,
  };
}
