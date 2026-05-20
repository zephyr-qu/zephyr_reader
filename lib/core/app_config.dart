import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  static AppConfig get instance => _instance;

  factory AppConfig() => _instance;

  AppConfig._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  static String baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.example.com';
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 10;
  static const int retries = 3;
  static final Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final enableDebugLogging = signal<bool>(true);
  final apiTimeout = signal<int>(30000);
  final defaultPageSize = signal<int>(20);

  static const String _keyDebugLogging = 'app.debug.logging';
  static const String _keyApiTimeout = 'app.api.timeout';
  static const String _keyDefaultPageSize = 'app.default.page.size';

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    await dotenv.load();
    _prefs = await SharedPreferences.getInstance();

    enableDebugLogging.value = _prefs!.getBool(_keyDebugLogging) ?? false;
    apiTimeout.value = _prefs!.getInt(_keyApiTimeout) ?? 30;
    defaultPageSize.value = _prefs!.getInt(_keyDefaultPageSize) ?? 20;

    _initialized = true;
  }

  Future<void> setDebugLogging(bool enabled) async {
    enableDebugLogging.value = enabled;
    await _prefs?.setBool(_keyDebugLogging, enabled);
  }

  Future<void> setApiTimeout(int timeout) async {
    apiTimeout.value = timeout;
    await _prefs?.setInt(_keyApiTimeout, timeout);
  }

  Future<void> setDefaultPageSize(int size) async {
    defaultPageSize.value = size;
    await _prefs?.setInt(_keyDefaultPageSize, size);
  }
}
