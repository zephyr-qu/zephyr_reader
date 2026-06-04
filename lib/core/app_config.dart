
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  static AppConfig get instance => _instance;

  factory AppConfig() => _instance;

  AppConfig._internal();

  bool _initialized = false;
  String _coverDir = '';

  bool get isInitialized => _initialized;
  String get coverDir => _coverDir;

  Future<void> init({String? coverDir}) async {
    if (_initialized) return;

    if (coverDir != null) {
      _coverDir = coverDir;
    }

    _initialized = true;
  }
}
