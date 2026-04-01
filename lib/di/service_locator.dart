import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'service_locator.config.dart';
import '../features/bookshelf/application/services/category_cache_service.dart';

final getIt = GetIt.instance;

/// 缓存服务实例（在 init 之前创建）
final categoryCacheService = CategoryCacheService();

@InjectableInit()
Future<void> configureDependencies() async {
  // 注册缓存服务
  getIt.registerLazySingleton<CategoryCacheService>(() => categoryCacheService);
  await getIt.init();
}
