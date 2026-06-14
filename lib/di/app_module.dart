// lib/di/app_module.dart
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';

@module
/// 应用模块，提供全局依赖的注入配置
abstract class AppModule {
  // @preResolve
  /// 预解析的 SharedPreferences 实例
  // Future<SharedPreferences> get prefs => SharedPreferences.getInstance();

  @preResolve // 确保异步初始化完成后再注入
  Future<SharedPreferencesService> providePreferencesService() {
    return SharedPreferencesService.create();
  }
}
