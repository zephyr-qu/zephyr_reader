import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';

@module
/// 应用模块，提供全局依赖的注入配置
abstract class AppModule {
  @preResolve
  Future<PreferencesService> providePreferencesService() {
    return SharedPreferencesService.create();
  }
}
