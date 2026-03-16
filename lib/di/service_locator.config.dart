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
import 'package:zephyr_reader/core/database/database.dart' as _i731;
import 'package:zephyr_reader/core/local/file_storage.dart' as _i772;
import 'package:zephyr_reader/core/network/network_module.dart' as _i510;
import 'package:zephyr_reader/core/reader/reader_config.dart' as _i849;
import 'package:zephyr_reader/di/app_module.dart' as _i431;
import 'package:zephyr_reader/di/database_module.dart' as _i559;
import 'package:zephyr_reader/features/article/application/article_view_model.dart'
    as _i556;
import 'package:zephyr_reader/features/article/data/article_api.dart' as _i569;
import 'package:zephyr_reader/features/article/data/article_service.dart'
    as _i582;
import 'package:zephyr_reader/features/article/domain/article_repository.dart'
    as _i523;
import 'package:zephyr_reader/features/auth/application/auth_view_model.dart'
    as _i563;
import 'package:zephyr_reader/features/auth/data/auth_api.dart' as _i60;
import 'package:zephyr_reader/features/auth/data/auth_service.dart' as _i738;
import 'package:zephyr_reader/features/auth/domain/auth_repository.dart'
    as _i304;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/bookshelf/data/bookshelf_service.dart'
    as _i167;
import 'package:zephyr_reader/features/bookshelf/domain/bookshelf_repository.dart'
    as _i208;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/data/reader_service.dart'
    as _i299;
import 'package:zephyr_reader/features/reader/domain/reader_repository.dart'
    as _i972;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/search/data/search_service.dart'
    as _i584;
import 'package:zephyr_reader/features/search/domain/search_repository.dart'
    as _i935;
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart'
    as _i988;
import 'package:zephyr_reader/features/sync/data/sync_service.dart' as _i456;
import 'package:zephyr_reader/features/sync/domain/sync_repository.dart'
    as _i317;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final appModule = _$AppModule();
    final databaseModule = _$DatabaseModule();
    final networkModule = _$NetworkModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => appModule.prefs,
      preResolve: true,
    );
    await gh.singletonAsync<_i731.AppDatabase>(
      () => databaseModule.database,
      preResolve: true,
    );
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i208.BookshelfRepository>(
      () => _i167.BookshelfService(gh<_i731.AppDatabase>()),
    );
    gh.lazySingleton<_i935.SearchRepository>(() => _i584.SearchService());
    gh.lazySingletonAsync<_i972.ReaderRepository>(
      () async => _i299.ReaderService(
        gh<_i731.AppDatabase>(),
        await getAsync<_i772.FileStorage>(),
      ),
    );
    gh.factory<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(gh<_i208.BookshelfRepository>()),
    );
    gh.factory<_i569.ArticleApi>(() => _i569.ArticleApi(gh<_i361.Dio>()));
    gh.factory<_i60.AuthApi>(
      () => _i60.AuthApi(gh<_i361.Dio>(), baseUrl: gh<String>()),
    );
    gh.lazySingleton<_i304.AuthRepository>(
      () => _i738.AuthService(gh<_i60.AuthApi>()),
    );
    gh.lazySingletonAsync<_i317.SyncRepository>(
      () async => _i456.SyncService(await getAsync<_i772.FileStorage>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i1.SearchViewModel>(
      () => _i1.SearchViewModel(gh<_i935.SearchRepository>()),
    );
    gh.factoryAsync<_i988.SyncViewModel>(
      () async => _i988.SyncViewModel(await getAsync<_i317.SyncRepository>()),
    );
    gh.factory<_i563.AuthViewModel>(
      () => _i563.AuthViewModel(gh<_i304.AuthRepository>()),
    );
    gh.lazySingleton<_i523.ArticleRepository>(
      () => _i582.ArticleService(gh<_i569.ArticleApi>()),
    );
    gh.factoryAsync<_i335.ReaderViewModel>(
      () async => _i335.ReaderViewModel(
        await getAsync<_i972.ReaderRepository>(),
        gh<_i849.ReaderConfig>(),
      ),
    );
    gh.factory<_i556.ArticleViewModel>(
      () => _i556.ArticleViewModel(gh<_i523.ArticleRepository>()),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$DatabaseModule extends _i559.DatabaseModule {}

class _$NetworkModule extends _i510.NetworkModule {}
