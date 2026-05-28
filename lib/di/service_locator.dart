import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart';

import 'service_locator.config.dart';

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.init();

  getIt.registerFactory<StorageSyncViewModel>(() => StorageSyncViewModel());
  getIt.registerFactory<LearningNotesViewModel>(() => LearningNotesViewModel());
  getIt.registerFactory<OtherSettingsViewModel>(() => OtherSettingsViewModel());
  getIt.registerFactory<ThemeBrightnessViewModel>(() => ThemeBrightnessViewModel());
}
