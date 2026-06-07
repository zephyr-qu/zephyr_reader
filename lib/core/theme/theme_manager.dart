import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// App主题类型枚举
enum AppThemeType {
  /// 浅色主题
  light,

  /// 深色主题
  dark,

  /// 跟随系统
  system,
}

extension AppThemeTypeX on AppThemeType {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    AppThemeType.light => l10n.themeLight,
    AppThemeType.dark => l10n.themeDark,
    AppThemeType.system => l10n.themeSystem,
  };
}

/// 主题管理器单
/// 主题管理器单例
///
/// 管理应用的主题状态，包括主题类型（浅色/深色/跟随系统）、
/// 语言偏好和自定义主题色。使用 signals 实现响应式状态管理，
/// 并提供主题持久化能力。
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  static ThemeManager get instance => _instance;

  ThemeManager._internal();

  SharedPreferences? _prefs;
  final List<void Function()> _disposers = [];
  bool _initialized = false;
  Future<void>? _initFuture;

  /// 当前主题类型信号
  final themeType = signal<AppThemeType>(AppThemeType.system);

  /// 当前语言信号（null = 跟随系统）
  final locale = signal<String?>(null);

  /// 自定义主题色信号（允许用户自定义主色
  final customPrimaryColor = signal<Color?>(null);

  /// 当前激活的主题预设 ID（null = 自定义颜色或默认）
  final currentPresetId = signal<String?>(null);

/// 获取 Flutter [ThemeMode]，将 [AppThemeType] 映射为 Material 主题模式
  ThemeMode get themeMode {
    switch (themeType.value) {
      case AppThemeType.light:
        return ThemeMode.light;
      case AppThemeType.dark:
        return ThemeMode.dark;
      case AppThemeType.system:
        return ThemeMode.system;
    }
  }

/// 当前是否为深色模式
///
/// 根据 [themeType] 和系统亮度判断当前实际深色状态
  bool get isDarkMode {
    final brightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    return switch (themeType.value) {
      AppThemeType.dark => true,
      AppThemeType.light => false,
      AppThemeType.system => brightness == Brightness.dark,
    };
  }

/// 初始化主题管理器，从 SharedPreferences 加载持久化的主题设置
  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    _prefs = await SharedPreferences.getInstance();

    // 加载主题类型
    final int themeIndex =
        _prefs!.getInt(SettingsKeys.themeType) ?? AppThemeType.system.index;
    final int resolvedIndex =
        themeIndex >= 0 && themeIndex < AppThemeType.values.length
        ? themeIndex
        : AppThemeType.system.index;
    themeType.value = AppThemeType.values[resolvedIndex];

    // 加载自定义主
    final colorValue = _prefs!.getInt(SettingsKeys.customPrimaryColor);
    if (colorValue != null) {
      customPrimaryColor.value = Color(colorValue);
    }

    // 加载主题预设
    currentPresetId.value = _prefs!.getString(SettingsKeys.currentPresetId);

    // 加载语言设置
    final savedLocale = _prefs!.getString(SettingsKeys.locale);
    if (savedLocale != null && ['zh', 'en'].contains(savedLocale)) {
      locale.value = savedLocale;
    }

    // 设置自动持久化 watcher
    _disposers.add(
      effect(() {
        _prefs!.setInt(SettingsKeys.themeType, themeType.value.index);
      }),
    );
    _disposers.add(
      effect(() {
        final v = customPrimaryColor.value;
        if (v != null) {
          _prefs!.setInt(SettingsKeys.customPrimaryColor, v.toARGB32());
        } else {
          _prefs!.remove(SettingsKeys.customPrimaryColor);
        }
      }),
    );
    _disposers.add(
      effect(() {
        final v = currentPresetId.value;
        if (v != null) {
          _prefs!.setString(SettingsKeys.currentPresetId, v);
        } else {
          _prefs!.remove(SettingsKeys.currentPresetId);
        }
      }),
    );
    _disposers.add(
      effect(() {
        final v = locale.value;
        if (v != null) {
          _prefs!.setString(SettingsKeys.locale, v);
        } else {
          _prefs!.remove(SettingsKeys.locale);
        }
      }),
    );

    _initialized = true;
  }

/// 获取应用当前 Locale（null 表示跟随系统）
  Locale? get appLocale {
    final code = locale.value;
    if (code == null) return null;
    return Locale(code);
  }

/// 设置自定义主色（同时更新主题预设 ID）
  Future<void> setCustomPrimaryColor(Color? color, {String? presetId}) async {
    customPrimaryColor.value = color;
    currentPresetId.value = presetId;
  }

/// 重置为主题默认色
  Future<void> resetCustomPrimaryColor() async {
    await setCustomPrimaryColor(null);
  }

  /// 释放所有 effect，允许热重载时重新初始化。
  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
    _initialized = false;
  }
}
