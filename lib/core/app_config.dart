
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  static AppConfig get instance => _instance;

  factory AppConfig() => _instance;

  AppConfig._internal();

  bool _initialized = false;

  bool get isInitialized => _initialized;


  Future<void> init() async {
    if (_initialized) return;


    _initialized = true;
  }

}
