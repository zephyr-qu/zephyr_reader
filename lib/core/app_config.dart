import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 应用配置单例类
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  static AppConfig get instance => _instance;

  factory AppConfig() => _instance;

  AppConfig._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  static String baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.example.com';
  static const int connectTimeout = 10000;
  static const int receiveTimeout = 10000;
  static const int retryDelaysTimeout = 500;
  static const int retries = 3;
  static Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final themeMode = signal<ThemeMode>(ThemeMode.system);
  final enableDebugLogging = signal<bool>(true);
  final apiTimeout = signal<int>(30000);
  final defaultPageSize = signal<int>(20);
  ThemeMode get currentMode => themeMode.value;

  static const String _keyThemeMode = 'app.theme.mode';
  static const String _keyDebugLogging = 'app.debug.logging';
  static const String _keyApiTimeout = 'app.api.timeout';
  static const String _keyDefaultPageSize = 'app.default.page.size';

  /// 是否已初始化
  bool get isInitialized => _initialized;

  /// 初始化配置
  Future<void> init() async {
    if (_initialized) return;

    await dotenv.load();
    _prefs = await SharedPreferences.getInstance();

    final int themeIndex =
        _prefs!.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    final int resolvedIndex =
        themeIndex >= 0 && themeIndex < ThemeMode.values.length
            ? themeIndex
            : ThemeMode.system.index;
    themeMode.value = ThemeMode.values[resolvedIndex];
    enableDebugLogging.value = _prefs!.getBool(_keyDebugLogging) ?? false;
    apiTimeout.value = _prefs!.getInt(_keyApiTimeout) ?? 30;
    defaultPageSize.value = _prefs!.getInt(_keyDefaultPageSize) ?? 20;

    _initialized = true;
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _prefs?.setInt(_keyThemeMode, mode.index);
  }

  /// 设置调试日志开关
  Future<void> setDebugLogging(bool enabled) async {
    enableDebugLogging.value = enabled;
    await _prefs?.setBool(_keyDebugLogging, enabled);
  }

  /// 设置API超时时间
  Future<void> setApiTimeout(int timeout) async {
    apiTimeout.value = timeout;
    await _prefs?.setInt(_keyApiTimeout, timeout);
  }

  /// 设置默认分页大小
  Future<void> setDefaultPageSize(int size) async {
    defaultPageSize.value = size;
    await _prefs?.setInt(_keyDefaultPageSize, size);
  }
}
