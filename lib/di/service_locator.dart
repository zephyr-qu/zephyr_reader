import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'service_locator.config.dart';
import '../features/bookshelf/application/services/category_cache_service.dart';
import '../features/reader/application/services/chapter_content_service.dart';

final getIt = GetIt.instance;

/// 缓存服务实例（在 init 之前创建）
final categoryCacheService = CategoryCacheService();

/// 章节内容服务实例（通过 Rust API 获取数据）
late ChapterContentService chapterContentService;

@InjectableInit()
Future<void> configureDependencies() async {
  // 注册缓存服务
  getIt.registerLazySingleton<CategoryCacheService>(() => categoryCacheService);

  // 注册章节内容服务（通过 Rust API 和文件系统获取数据）
  chapterContentService = ChapterContentService();
  getIt.registerLazySingleton<ChapterContentService>(
    () => chapterContentService,
  );

  await getIt.init();
}
