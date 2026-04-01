import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 主题类型枚举
enum AppThemeType {
  /// 浅色主题
  light(label: '浅色'),

  /// 深色主题
  dark(label: '深色'),

  /// 纯黑主题 (AMOLED)
  pureDark(label: '纯黑'),

  /// 护眼主题 (米黄
  eyeProtection(label: '护眼'),

  /// 跟随系统
  system(label: '系统');

  final String label;
  const AppThemeType({required this.label});
}

/// 主题管理器单
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  static ThemeManager get instance => _instance;

  factory ThemeManager() => _instance;

  ThemeManager._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  /// 当前主题类型信号
  final themeType = signal<AppThemeType>(AppThemeType.system);

  /// 自定义主题色信号（允许用户自定义主色
  final customPrimaryColor = signal<Color?>(null);

  /// 主题模式（兼Flutter ThemeMode
  ThemeMode get themeMode {
    switch (themeType.value) {
      case AppThemeType.light:
        return ThemeMode.light;
      case AppThemeType.dark:
        return ThemeMode.dark;
      case AppThemeType.pureDark:
        return ThemeMode.dark;
      case AppThemeType.eyeProtection:
        return ThemeMode.light;
      case AppThemeType.system:
        return ThemeMode.system;
    }
  }

  /// 是否为深色模
  bool get isDarkMode {
    switch (themeType.value) {
      case AppThemeType.dark:
      case AppThemeType.pureDark:
        return true;
      case AppThemeType.light:
      case AppThemeType.eyeProtection:
        return false;
      case AppThemeType.system:
        final brightness =
            SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  static const String _keyThemeType = 'app.theme.type';
  static const String _keyCustomPrimaryColor = 'app.theme.custom_color';

  /// 初始化主题管理器
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();

    // 加载主题类型
    final int themeIndex =
        _prefs!.getInt(_keyThemeType) ?? AppThemeType.system.index;
    final int resolvedIndex =
        themeIndex >= 0 && themeIndex < AppThemeType.values.length
        ? themeIndex
        : AppThemeType.system.index;
    themeType.value = AppThemeType.values[resolvedIndex];

    // 加载自定义主
    final colorValue = _prefs!.getInt(_keyCustomPrimaryColor);
    if (colorValue != null) {
      customPrimaryColor.value = Color(colorValue);
    }

    _initialized = true;
  }

  /// 设置主题类型
  Future<void> setThemeType(AppThemeType type) async {
    themeType.value = type;
    await _prefs?.setInt(_keyThemeType, type.index);
  }

  /// 设置自定义主
  Future<void> setCustomPrimaryColor(Color? color) async {
    customPrimaryColor.value = color;
    if (color != null) {
      // 使用 toARGB32() 替代已弃用的 value
      await _prefs?.setInt(_keyCustomPrimaryColor, color.toARGB32());
    } else {
      await _prefs?.remove(_keyCustomPrimaryColor);
    }
  }

  /// 重置为主题默认色
  Future<void> resetCustomPrimaryColor() async {
    await setCustomPrimaryColor(null);
  }

  /// 获取所有可用的主题预设
  List<ThemePreset> getAvailablePresets() {
    return [
      const ThemePreset(
        id: 'default_teal',
        name: '清新青绿',
        primaryColor: Color(0xFF2DD4BF),
        description: '清新主题，清新活跃',
      ),
      const ThemePreset(
        id: 'ocean_blue',
        name: '海洋',
        primaryColor: Color(0xFF3B82F6),
        description: '沉稳专业',
      ),
      const ThemePreset(
        id: 'forest_green',
        name: '森林',
        primaryColor: Color(0xFF10B981),
        description: '自然护眼',
      ),
      const ThemePreset(
        id: 'sunset_orange',
        name: '日落',
        primaryColor: Color(0xFFF97316),
        description: '温暖活力',
      ),
      const ThemePreset(
        id: 'royal_purple',
        name: '贵族',
        primaryColor: Color(0xFF8B5CF6),
        description: '优雅神秘',
      ),
      const ThemePreset(
        id: 'rose_pink',
        name: '玫瑰',
        primaryColor: Color(0xFFEC4899),
        description: '浪漫温馨',
      ),
    ];
  }

  /// 应用主题预设
  Future<void> applyPreset(String presetId) async {
    final presets = getAvailablePresets();
    final preset = presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => presets.first,
    );
    await setCustomPrimaryColor(preset.primaryColor);
  }

  /// 获取当前主题的名
  String get currentThemeName => themeType.value.label;

  /// 是否为护眼模
  bool get isEyeProtectionMode => themeType.value == AppThemeType.eyeProtection;

  /// 是否为纯黑模
  bool get isPureDarkMode => themeType.value == AppThemeType.pureDark;
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
