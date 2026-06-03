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
import 'package:shared_preferences/shared_preferences.dart' as _i460;
import 'package:zephyr_reader/core/local/file_storage.dart' as _i772;
import 'package:zephyr_reader/core/network/network_module.dart' as _i510;
import 'package:zephyr_reader/core/network/wifi_transfer_service.dart' as _i82;
import 'package:zephyr_reader/core/reader/custom_font_service.dart' as _i851;
import 'package:zephyr_reader/core/reader/reader_config.dart' as _i849;
import 'package:zephyr_reader/core/reader/tts_service.dart' as _i825;
import 'package:zephyr_reader/di/app_module.dart' as _i431;
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart'
    as _i341;
import 'package:zephyr_reader/features/bookshelf/application/book_detail_view_model.dart'
    as _i596;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/home/application/home_view_model.dart'
    as _i363;
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart'
    as _i676;
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart'
    as _i340;
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart'
    as _i640;
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart'
    as _i489;
import 'package:zephyr_reader/features/reader/application/annotation_controller.dart'
    as _i693;
import 'package:zephyr_reader/features/reader/application/bilingual_controller.dart'
    as _i346;
import 'package:zephyr_reader/features/reader/application/bookmark_controller.dart'
    as _i891;
import 'package:zephyr_reader/features/reader/application/reader_search_controller.dart'
    as _i291;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart'
    as _i1054;
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart'
    as _i880;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/statistics/application/reading_sessions_view_model.dart'
    as _i799;
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart'
    as _i1072;
import 'package:zephyr_reader/features/statistics/application/statistics_view_model.dart'
    as _i540;
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart'
    as _i657;
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart'
    as _i104;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    final networkModule = _$NetworkModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => appModule.prefs,
      preResolve: true,
    );
    gh.factory<_i363.HomeViewModel>(() => _i363.HomeViewModel());
    gh.factory<_i676.LearningNotesViewModel>(
      () => _i676.LearningNotesViewModel(),
    );
    gh.factory<_i693.AnnotationController>(() => _i693.AnnotationController());
    gh.factory<_i346.BilingualController>(() => _i346.BilingualController());
    gh.factory<_i291.ReaderSearchController>(
      () => _i291.ReaderSearchController(),
    );
    gh.factory<_i1054.ReaderRepository>(() => _i1054.ReaderRepository());
    gh.factory<_i1.SearchViewModel>(() => _i1.SearchViewModel());
    gh.factory<_i799.ReadingSessionsViewModel>(
      () => _i799.ReadingSessionsViewModel(),
    );
    gh.factory<_i540.StatisticsViewModel>(() => _i540.StatisticsViewModel());
    gh.factory<_i657.StorageSyncViewModel>(() => _i657.StorageSyncViewModel());
    gh.factory<_i104.VocabularyViewModel>(() => _i104.VocabularyViewModel());
    gh.singleton<_i849.ReaderBgColors>(() => _i849.ReaderBgColors());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i825.TtsService>(() => _i825.TtsService());
    gh.lazySingleton<_i340.ProfileViewModel>(() => _i340.ProfileViewModel());
    gh.lazySingleton<_i880.VocabularyMarkerService>(
      () => _i880.VocabularyMarkerService(),
    );
    gh.lazySingleton<_i1072.ReadingStatsViewModel>(
      () => _i1072.ReadingStatsViewModel(),
    );
    gh.factory<_i891.BookmarkController>(
      () => _i891.BookmarkController(gh<_i1054.ReaderRepository>()),
    );
    gh.factory<_i596.BookDetailViewModel>(
      () => _i596.BookDetailViewModel(bookId: gh<String>()),
    );
    gh.singleton<_i82.WifiTransferService>(
      () => _i82.WifiTransferService(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i851.FontRepository>(
      () => _i851.FontRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i341.BackupViewModel>(
      () => _i341.BackupViewModel(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i640.OtherSettingsViewModel>(
      () => _i640.OtherSettingsViewModel(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i489.ThemeBrightnessViewModel>(
      () => _i489.ThemeBrightnessViewModel(gh<_i460.SharedPreferences>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingleton<_i335.ReaderViewModel>(
      () => _i335.ReaderViewModel(
        gh<_i1054.ReaderRepository>(),
        gh<_i849.ReaderConfig>(),
        gh<_i891.BookmarkController>(),
        gh<_i291.ReaderSearchController>(),
        gh<_i693.AnnotationController>(),
        gh<_i346.BilingualController>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}
