import 'package:get_it/get_it.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_import_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart';
import 'package:zephyr_reader/features/data/application/backup_view_model.dart';
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/application/theme_brightness_view_model.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';

/// 全局服务定位器实例
final getIt = GetIt.instance;

/// 手写注册：依赖总共 10 个，不值得维护 injectable 代码生成链。
Future<void> configureDependencies() async {
  final PreferencesService prefs = await SharedPreferencesService.create();
  getIt
    ..registerSingleton<PreferencesService>(prefs)
    ..registerFactory<CategoryViewModel>(CategoryViewModel.new)
    ..registerSingleton<ReaderBgColors>(ReaderBgColors())
    ..registerLazySingleton<BookImportService>(BookImportService.new)
    ..registerLazySingleton<BookshelfViewModel>(
      () => BookshelfViewModel(prefs, getIt<CategoryViewModel>()),
    )
    ..registerFactory<OtherSettingsViewModel>(() => OtherSettingsViewModel(prefs))
    ..registerFactory<ThemeBrightnessViewModel>(
      () => ThemeBrightnessViewModel(prefs),
    )
    ..registerFactory<TtsSettingsViewModel>(() => TtsSettingsViewModel(prefs))
    ..registerLazySingleton<BackupViewModel>(() => BackupViewModel(prefs))
    ..registerSingleton<ReaderConfig>(ReaderConfig(prefs))
    ..registerSingleton<ThemeManager>(ThemeManager(prefs));
}
