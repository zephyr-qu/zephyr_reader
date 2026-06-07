/// 应用全局配置
///
/// 单例模式，管理应用的初始化状态和运行时目录配置。
/// 启动时通过 [init] 初始化，初始化后可通过 [instance] 全局访问。

class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  static AppConfig get instance => _instance;

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
