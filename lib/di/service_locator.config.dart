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
import 'package:zephyr_reader/core/theme/theme_manager.dart' as _i182;
import 'package:zephyr_reader/di/app_module.dart' as _i431;
import 'package:zephyr_reader/features/bookshelf/application/book_import_service.dart'
    as _i339;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart'
    as _i5;
import 'package:zephyr_reader/features/data/application/backup_view_model.dart'
    as _i1022;
import 'package:zephyr_reader/features/data/application/data_management_view_model.dart'
    as _i965;
import 'package:zephyr_reader/features/data/application/services/webdav_sync_service.dart'
    as _i415;
import 'package:zephyr_reader/features/profile/application/dictionary_settings_view_model.dart'
    as _i236;
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart'
    as _i362;
import 'package:zephyr_reader/features/profile/application/theme_brightness_view_model.dart'
    as _i583;
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart'
    as _i136;
import 'package:zephyr_reader/features/reader/core/application/reader_session.dart'
    as _i305;
import 'package:zephyr_reader/features/reader/core/data/pagination_session_factory.dart'
    as _i693;
import 'package:zephyr_reader/features/reader/core/data/rust_chapter_content_repository.dart'
    as _i109;
import 'package:zephyr_reader/features/reader/core/data/rust_progress_repository.dart'
    as _i433;
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart'
    as _i291;
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart'
    as _i768;
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart'
    as _i880;
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart'
    as _i402;
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart'
    as _i693;
import 'package:zephyr_reader/features/reader/domain/service/tts_service.dart'
    as _i1020;
import 'package:zephyr_reader/features/reader/translation/application/translation_config.dart'
    as _i466;
import 'package:zephyr_reader/features/reader/translation/data/translation_module.dart'
    as _i401;
import 'package:zephyr_reader/features/reader/translation/domain/translation_service.dart'
    as _i877;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;

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
    gh.factory<_i965.DataManagementViewModel>(
      () => _i965.DataManagementViewModel(),
    );
    gh.factory<_i693.PaginationSessionFactory>(
      () => _i693.PaginationSessionFactory(),
    );
    gh.singleton<_i402.ReaderBgColors>(() => _i402.ReaderBgColors());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i339.BookImportService>(() => _i339.BookImportService());
    gh.lazySingleton<_i415.WebDavSyncService>(() => _i415.WebDavSyncService());
    gh.lazySingleton<_i880.VocabularyMarkerService>(
      () => _i880.VocabularyMarkerService(),
    );
    gh.lazySingleton<_i1020.TtsService>(() => _i1020.TtsService());
    gh.lazySingleton<_i1.SearchViewModel>(() => _i1.SearchViewModel());
    gh.factory<_i291.ChapterContentRepository>(
      () => _i109.RustChapterContentRepository(),
    );
    gh.factory<_i768.ProgressRepository>(() => _i433.RustProgressRepository());
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
    gh.singleton<_i693.FontRepository>(
      () => _i693.FontRepository(gh<_i985.PreferencesService>()),
    );
    gh.lazySingleton<_i1022.BackupViewModel>(
      () => _i1022.BackupViewModel(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i182.ThemeManager>(
      () => _i182.ThemeManager(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i402.ReaderConfig>(
      () => _i402.ReaderConfig(gh<_i985.PreferencesService>()),
    );
    gh.singleton<_i466.TranslationConfig>(
      () => _i466.TranslationConfig(gh<_i985.PreferencesService>()),
    );
    gh.factory<_i305.ReaderSessionFactory>(
      () => _i305.ReaderSessionFactory(
        gh<_i291.ChapterContentRepository>(),
        gh<_i768.ProgressRepository>(),
        gh<_i693.PaginationSessionFactory>(),
        gh<_i402.ReaderConfig>(),
      ),
    );
    gh.lazySingleton<_i877.TranslationService>(
      () => translationModule.translationService(
        gh<_i466.TranslationConfig>(),
        gh<_i361.Dio>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}

class _$TranslationModule extends _i401.TranslationModule {}
