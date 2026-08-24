import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/di/service_locator.dart';

/// App主题类型枚举
enum AppThemeType {
  /// 浅色主题
  light,

  /// 深色主题
  dark,

  /// 跟随系统
  system,
}

/// 主题管理器
///
/// 管理应用的主题状态，包括主题类型（浅色/深色/跟随系统）、
/// 语言偏好和自定义主题色。使用 persisted signals 实现自动持久化。
@Singleton()
class ThemeManager {
  final PreferencesService prefs;

  /// 当前主题类型
  late final themeType = persisted<AppThemeType>(
    prefs,
    SettingsKeys.themeType,
    AppThemeType.system,
    reader: (p, k) {
      // 兼容旧格式（int index），新格式为 string name
      final str = p.getString(k);
      if (str != null) {
        try {
          return AppThemeType.values.byName(str);
        } catch (e) {
          Logging.debug('主题类型解析失败，回退到索引方式: $e');
        }
      }
      final idx = p.getIntOrNull(k);
      if (idx != null && idx >= 0 && idx < AppThemeType.values.length) {
        return AppThemeType.values[idx];
      }
      return AppThemeType.system;
    },
    writer: (p, k, v) => p.setString(k, v.name),
    debounce: Duration.zero,
  );

  /// 当前语言信号（null = 跟随系统）
  late final locale = persisted<String?>(
    prefs,
    SettingsKeys.locale,
    null,
    reader: (p, k) {
      final v = p.getString(k);
      if (v != null && ['zh', 'en'].contains(v)) return v;
      return null;
    },
    writer: (p, k, v) async {
      if (v != null) {
        await p.setString(k, v);
      } else {
        await p.remove(k);
      }
    },
    debounce: Duration.zero,
  );

  /// 自定义主题色信号（允许用户自定义主色）
  late final customPrimaryColor = persistedColor(
    prefs,
    SettingsKeys.customPrimaryColor,
    debounce: Duration.zero,
  );

  /// 当前激活的主题预设 ID（null = 自定义颜色或默认）
  late final currentPresetId = persisted<String?>(
    prefs,
    SettingsKeys.currentPresetId,
    null,
    reader: (p, k) => p.getString(k),
    writer: (p, k, v) async {
      if (v != null) {
        await p.setString(k, v);
      } else {
        await p.remove(k);
      }
    },
    debounce: Duration.zero,
  );

  ThemeManager(this.prefs);

  /// 兼容旧调用方 — 通过 DI 获取实例
  static ThemeManager get instance => getIt<ThemeManager>();

  /// 获取 Flutter [ThemeMode]，将 [AppThemeType] 映射为 Material 主题模式
  ThemeMode get themeMode {
    return switch (themeType.value) {
      AppThemeType.light => ThemeMode.light,
      AppThemeType.dark => ThemeMode.dark,
      AppThemeType.system => ThemeMode.system,
    };
  }

  /// 当前是否为深色模式
  ///
  /// 根据 [themeType] 和系统亮度判断当前实际深色状态
  bool get isDarkMode {
    return switch (themeType.value) {
      AppThemeType.dark => true,
      AppThemeType.light => false,
      AppThemeType.system =>
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  /// 获取应用当前 Locale（null 表示跟随系统）
  Locale? get appLocale {
    final lang = locale.value;
    return lang != null ? Locale(lang) : null;
  }

  /// 设置自定义主色（同时更新主题预设 ID）
  Future<void> setCustomPrimaryColor(Color? color, {String? presetId}) async {
    customPrimaryColor.value = color;
    if (presetId != null) currentPresetId.value = presetId;
  }

  /// 重置为主题默认色
  Future<void> resetCustomPrimaryColor() async {
    await setCustomPrimaryColor(null);
  }

  /// 释放所有 signal 资源。
  void dispose() {
    themeType.dispose();
    locale.dispose();
    customPrimaryColor.dispose();
    currentPresetId.dispose();
  }
}
