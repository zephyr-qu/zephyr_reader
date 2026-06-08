// lib/di/app_module.dart
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@module
/// 应用模块，提供全局依赖的注入配置
abstract class AppModule {
  @preResolve
  /// 预解析的 SharedPreferences 实例
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
