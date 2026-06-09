import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/features/sync/application/services/webdav_sync_service.dart';

import 'service_locator.config.dart';

/// 全局服务定位器实例
final getIt = GetIt.instance;

/// 配置依赖注入
@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.init();
  getIt.registerLazySingleton<WebDavSyncService>(() => WebDavSyncService());
  final fontRepo = FontRepository(getIt<SharedPreferences>());
  await fontRepo.init();
  getIt.registerSingleton<FontRepository>(fontRepo);
}
