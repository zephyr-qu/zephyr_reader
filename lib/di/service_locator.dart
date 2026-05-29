import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/features/bookshelf/application/book_detail_view_model.dart';
import 'package:zephyr_reader/features/statistics/application/statistics_view_model.dart';
import 'package:zephyr_reader/features/statistics/application/reading_sessions_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart';
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart';
import 'package:zephyr_reader/features/sync/domain/repositories/sync_repository.dart';

import 'service_locator.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.init();

  getIt.registerFactory<StorageSyncViewModel>(() => StorageSyncViewModel());

  // SyncRepository 是 lazySingletonAsync，导致 injectable 将 SyncViewModel
  // 生成为 factoryAsync。但 SyncViewModel 构造器是同步的，且各方以同步方式
  // 使用（getIt<SyncViewModel>()），故手动注册为同步单例。
  final repo = await getIt.getAsync<SyncRepository>();
  getIt.allowReassignment = true;
  getIt.registerSingleton<SyncViewModel>(SyncViewModel(repo));
  getIt.allowReassignment = false;
  getIt.registerFactory<LearningNotesViewModel>(() => LearningNotesViewModel());
  getIt.registerFactory<OtherSettingsViewModel>(() => OtherSettingsViewModel());
  getIt.registerFactory<ThemeBrightnessViewModel>(
    () => ThemeBrightnessViewModel(),
  );
  getIt.registerFactory<ReadingSessionsViewModel>(
    () => ReadingSessionsViewModel(),
  );
  getIt.registerFactoryParam<BookDetailViewModel, String, void>(
    (bookId, _) => BookDetailViewModel(bookId: bookId),
  );
  getIt.registerFactory<StatisticsViewModel>(() => StatisticsViewModel());
}
