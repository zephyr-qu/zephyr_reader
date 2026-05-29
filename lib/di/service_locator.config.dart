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
import 'package:zephyr_reader/features/article/application/article_view_model.dart'
    as _i556;
import 'package:zephyr_reader/features/article/data/article_api.dart' as _i569;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/home/application/home_view_model.dart'
    as _i363;
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart'
    as _i340;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart'
    as _i1054;
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart'
    as _i880;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart'
    as _i1072;
import 'package:zephyr_reader/features/sync/data/sync_service.dart' as _i456;
import 'package:zephyr_reader/features/sync/domain/repositories/sync_repository.dart'
    as _i499;
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
    gh.factory<_i340.ProfileViewModel>(() => _i340.ProfileViewModel());
    gh.factory<_i1054.ReaderRepository>(() => _i1054.ReaderRepository());
    gh.factory<_i1.SearchViewModel>(() => _i1.SearchViewModel());
    gh.factory<_i104.VocabularyViewModel>(() => _i104.VocabularyViewModel());
    gh.singleton<_i849.ReaderBgColors>(() => _i849.ReaderBgColors());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i82.WifiTransferService>(
      () => _i82.WifiTransferService(),
    );
    gh.lazySingleton<_i825.TtsService>(() => _i825.TtsService());
    gh.lazySingleton<_i880.VocabularyMarkerService>(
      () => _i880.VocabularyMarkerService(),
    );
    gh.lazySingleton<_i1072.ReadingStatsViewModel>(
      () => _i1072.ReadingStatsViewModel(),
    );
    gh.factory<_i569.ArticleApi>(() => _i569.ArticleApi(gh<_i361.Dio>()));
    gh.factory<_i851.FontRepository>(
      () => _i851.FontRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingletonAsync<_i499.SyncRepository>(
      () async => _i456.SyncRepository(await getAsync<_i772.FileStorage>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i556.ArticleViewModel>(
      () => _i556.ArticleViewModel(gh<_i569.ArticleApi>()),
    );
    gh.lazySingleton<_i335.ReaderViewModel>(
      () => _i335.ReaderViewModel(
        gh<_i1054.ReaderRepository>(),
        gh<_i849.ReaderConfig>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}
