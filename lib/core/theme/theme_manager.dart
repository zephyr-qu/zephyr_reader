import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';

/// 主题类型枚举
enum AppThemeType {
  /// 浅色主题
  light(label: '浅色'),

  /// 深色主题
  dark(label: '深色'),

  /// 跟随系统
  system(label: '系统');

  final String label;
  const AppThemeType({required this.label});
}

/// 主题管理器单
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  static ThemeManager get instance => _instance;


  ThemeManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// 当前主题类型信号
  final themeType = signal<AppThemeType>(AppThemeType.system);

  /// 当前语言信号（null = 跟随系统）
  final locale = signal<String?>(null);

  /// 自定义主题色信号（允许用户自定义主色
  final customPrimaryColor = signal<Color?>(null);

  /// 当前激活的主题预设 ID（null = 自定义颜色或默认）
  final currentPresetId = signal<String?>(null);

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

  /// 是否为深色模式
  bool get isDarkMode {
    switch (themeType.value) {
      case AppThemeType.dark:
        return true;
      case AppThemeType.light:
        return false;
      case AppThemeType.system:
        final brightness =
            SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  /// 初始化主题管理器
  Future<void> init() async {
    if (_initialized) return;

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
    effect(() {
      _prefs!.setInt(SettingsKeys.themeType, themeType.value.index);
    });
    effect(() {
      final v = customPrimaryColor.value;
      if (v != null) {
        _prefs!.setInt(SettingsKeys.customPrimaryColor, v.toARGB32());
      } else {
        _prefs!.remove(SettingsKeys.customPrimaryColor);
      }
    });
    effect(() {
      final v = currentPresetId.value;
      if (v != null) {
        _prefs!.setString(SettingsKeys.currentPresetId, v);
      } else {
        _prefs!.remove(SettingsKeys.currentPresetId);
      }
    });
    effect(() {
      final v = locale.value;
      if (v != null) {
        _prefs!.setString(SettingsKeys.locale, v);
      } else {
        _prefs!.remove(SettingsKeys.locale);
      }
    });

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

  /// 获取所有可用的主题预设（精简为 4 个）
  List<ThemePreset> getAvailablePresets() {
    return [
      const ThemePreset(
        id: 'gleam_cyan',
        name: '莹光青',
        primaryColor: Color(0xFF07D2D7),
        description: '清新现代（默认）',
      ),
      const ThemePreset(
        id: 'night_blue',
        name: '静夜蓝',
        primaryColor: Color(0xFF3B82F6),
        description: '沉稳专注',
      ),
      const ThemePreset(
        id: 'warm_amber',
        name: '暖枫',
        primaryColor: Color(0xFFF59E0B),
        description: '温暖舒适',
      ),
      const ThemePreset(
        id: 'mist_violet',
        name: '薄雾紫',
        primaryColor: Color(0xFF8B5CF6),
        description: '优雅神秘',
      ),
    ];
  }

  Future<void> applyPreset(String presetId) async {
    final presets = getAvailablePresets();
    final preset = presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => presets.first,
    );
    await setCustomPrimaryColor(preset.primaryColor, presetId: preset.id);
  }

  /// 获取当前主题的名
  String get currentThemeName => themeType.value.label;

}

/// 主题预设
class ThemePreset {
  final String id;
  final String name;
  final Color primaryColor;
  final String description;

  const ThemePreset({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.description,
  });
}
