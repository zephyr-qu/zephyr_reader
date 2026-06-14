// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:zephyr_reader/core/local/file_storage.dart' as _i772;
import 'package:zephyr_reader/core/local/preferences_service.dart' as _i985;
import 'package:zephyr_reader/core/network/network_module.dart' as _i510;
import 'package:zephyr_reader/core/network/wifi_transfer_service.dart' as _i82;
import 'package:zephyr_reader/core/reader/custom_font_service.dart' as _i851;
import 'package:zephyr_reader/core/reader/reader_config.dart' as _i849;
import 'package:zephyr_reader/core/reader/tts_service.dart' as _i825;
import 'package:zephyr_reader/core/theme/theme_manager.dart' as _i182;
import 'package:zephyr_reader/di/app_module.dart' as _i431;
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart'
    as _i341;
import 'package:zephyr_reader/features/bookshelf/application/book_import_service.dart'
    as _i339;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart'
    as _i5;
import 'package:zephyr_reader/features/profile/application/dictionary_settings_view_model.dart'
    as _i236;
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart'
    as _i362;
import 'package:zephyr_reader/features/profile/application/theme_brightness_view_model.dart'
    as _i583;
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart'
    as _i136;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/application/translation_config.dart'
    as _i888;
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart'
    as _i1054;
import 'package:zephyr_reader/features/reader/data/translation/translation_module.dart'
    as _i1038;
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart'
    as _i880;
import 'package:zephyr_reader/features/reader/domain/translation_service.dart'
    as _i625;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/sync/application/services/webdav_sync_service.dart'
    as _i9;
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart'
    as _i657;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    final networkModule = _$NetworkModule();
    final translationModule = _$TranslationModule();
    await gh.factoryAsync<_i985.PreferencesService>(
      () => appModule.providePreferencesService(),
      preResolve: true,
    );
    gh.factory<_i5.CategoryViewModel>(() => _i5.CategoryViewModel());
    gh.factory<_i1054.ReaderRepository>(() => _i1054.ReaderRepository());
    gh.factory<_i657.StorageSyncViewModel>(() => _i657.StorageSyncViewModel());
    gh.singleton<_i849.ReaderBgColors>(() => _i849.ReaderBgColors());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i825.TtsService>(() => _i825.TtsService());
    gh.lazySingleton<_i339.BookImportService>(() => _i339.BookImportService());
    gh.lazySingleton<_i880.VocabularyMarkerService>(
      () => _i880.VocabularyMarkerService(),
    );
    gh.lazySingleton<_i1.SearchViewModel>(() => _i1.SearchViewModel());
    gh.lazySingleton<_i9.WebDavSyncService>(() => _i9.WebDavSyncService());
    gh.lazySingleton<_i335.ReaderViewModel>(
      () => _i335.ReaderViewModel(
        repo: gh<_i1054.ReaderRepository>(),
        config: gh<_i849.ReaderConfig>(),
      ),
    );
    gh.lazySingleton<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(
        gh<_i985.PreferencesService>(),
        gh<_i5.CategoryViewModel>(),
      ),
    );
    gh.factory<_i236.DictionarySettingsViewModel>(
      () => _i236.DictionarySettingsViewModel(gh<_i985.PreferencesService>()),
    );
    gh.factory<_i362.OtherSettingsViewModel>(
      () => _i362.OtherSettingsViewModel(gh<_i985.PreferencesService>()),
    );
    gh.factory<_i583.ThemeBrightnessViewModel>(
      () => _i583.ThemeBrightnessViewModel(gh<_i985.PreferencesService>()),
    );
    gh.factory<_i136.TtsSettingsViewModel>(
      () => _i136.TtsSettingsViewModel(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i82.WifiTransferService>(
      () => _i82.WifiTransferService(gh<_i985.PreferencesService>()),
    );
    await gh.singleton<_i851.FontRepository>(
      () => _i851.FontRepository(gh<_i985.PreferencesService>()),
      preResolve: true,
    );
    gh.lazySingleton<_i341.BackupViewModel>(
      () => _i341.BackupViewModel(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i182.ThemeManager>(
      () => _i182.ThemeManager(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i888.TranslationConfig>(
      () => _i888.TranslationConfig(gh<_i985.PreferencesService>()),
    );
    gh.lazySingleton<_i625.TranslationService>(
      () => translationModule.translationService(
        gh<_i888.TranslationConfig>(),
        gh<_i361.Dio>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}

class _$TranslationModule extends _i1038.TranslationModule {}
