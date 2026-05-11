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
import 'package:zephyr_reader/core/local/rust_core_service.dart' as _i607;
import 'package:zephyr_reader/core/local/rust_cover_service.dart' as _i14;
import 'package:zephyr_reader/core/local/rust_epub_service.dart' as _i633;
import 'package:zephyr_reader/core/local/rust_search_service.dart' as _i148;
import 'package:zephyr_reader/core/local/rust_storage_service.dart' as _i169;
import 'package:zephyr_reader/core/network/network_module.dart' as _i510;
import 'package:zephyr_reader/core/reader/reader_config.dart' as _i849;
import 'package:zephyr_reader/di/app_module.dart' as _i431;
import 'package:zephyr_reader/features/article/application/article_view_model.dart'
    as _i556;
import 'package:zephyr_reader/features/article/data/article_api.dart' as _i569;
import 'package:zephyr_reader/features/article/data/article_service.dart'
    as _i582;
import 'package:zephyr_reader/features/article/domain/repositories/article_repository.dart'
    as _i29;
import 'package:zephyr_reader/features/auth/application/auth_view_model.dart'
    as _i563;
import 'package:zephyr_reader/features/auth/data/auth_api.dart' as _i60;
import 'package:zephyr_reader/features/auth/data/auth_service.dart' as _i738;
import 'package:zephyr_reader/features/auth/domain/repositories/auth_repository.dart'
    as _i878;
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/bookshelf/application/services/book_import_service.dart'
    as _i715;
import 'package:zephyr_reader/features/bookshelf/application/services/book_import_service_v2.dart'
    as _i39;
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart'
    as _i377;
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_settings_service.dart'
    as _i265;
import 'package:zephyr_reader/features/bookshelf/application/services/category_cache_service.dart'
    as _i702;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart'
    as _i682;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_bookmark_repository.dart'
    as _i565;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_chapter_repository.dart'
    as _i454;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart'
    as _i134;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/bookmark_repository.dart'
    as _i1052;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/chapter_repository.dart'
    as _i821;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/application/services/chapter_content_service.dart'
    as _i817;
import 'package:zephyr_reader/features/reader/data/custom_font_service.dart'
    as _i601;
import 'package:zephyr_reader/features/reader/data/layout_cache_service.dart'
    as _i365;
import 'package:zephyr_reader/features/reader/data/note_service.dart' as _i759;
import 'package:zephyr_reader/features/reader/data/reading_progress_service.dart'
    as _i189;
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart'
    as _i1054;
import 'package:zephyr_reader/features/reader/domain/repositories/reader_repository.dart'
    as _i537;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/search/data/search_service.dart'
    as _i584;
import 'package:zephyr_reader/features/search/domain/repositories/search_repository.dart'
    as _i384;
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart'
    as _i1072;
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart'
    as _i988;
import 'package:zephyr_reader/features/sync/data/sync_service.dart' as _i456;
import 'package:zephyr_reader/features/sync/domain/repositories/sync_repository.dart'
    as _i499;

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
    gh.factory<_i715.BookImportService>(() => _i715.BookImportService());
    gh.factory<_i817.ChapterContentService>(
      () => _i817.ChapterContentService(),
    );
    gh.singleton<_i169.RustStorageService>(() => _i169.RustStorageService());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i607.RustCoreService>(() => _i607.RustCoreService());
    gh.lazySingleton<_i14.RustCoverService>(() => _i14.RustCoverService());
    gh.lazySingleton<_i633.RustEpubService>(() => _i633.RustEpubService());
    gh.lazySingleton<_i148.RustSearchService>(() => _i148.RustSearchService());
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i702.CategoryCacheService>(
      () => _i702.CategoryCacheService(),
    );
    gh.lazySingleton<_i384.SearchRepository>(() => _i584.SearchService());
    gh.factory<_i1.SearchViewModel>(
      () => _i1.SearchViewModel(gh<_i384.SearchRepository>()),
    );
    gh.factory<_i569.ArticleApi>(() => _i569.ArticleApi(gh<_i361.Dio>()));
    gh.factory<_i60.AuthApi>(() => _i60.AuthApi(gh<_i361.Dio>()));
    gh.lazySingleton<_i29.ArticleRepository>(
      () => _i582.ArticleService(gh<_i569.ArticleApi>()),
    );
    gh.lazySingleton<_i878.AuthRepository>(
      () => _i738.AuthService(gh<_i60.AuthApi>()),
    );
    gh.factory<_i39.BookImportServiceV2>(
      () => _i39.BookImportServiceV2(
        gh<_i607.RustCoreService>(),
        gh<_i14.RustCoverService>(),
      ),
    );
    gh.singleton<_i265.BookshelfSettingsService>(
      () => _i265.BookshelfSettingsService(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i601.CustomFontService>(
      () => _i601.CustomFontService(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i556.ArticleViewModel>(
      () => _i556.ArticleViewModel(gh<_i29.ArticleRepository>()),
    );
    gh.factory<_i821.ChapterRepository>(
      () => _i454.RustChapterRepository(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i365.LayoutCacheService>(
      () => _i365.LayoutCacheService(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i759.NoteService>(
      () => _i759.NoteService(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i189.ReadingProgressService>(
      () => _i189.ReadingProgressService(gh<_i169.RustStorageService>()),
    );
    gh.lazySingleton<_i1072.ReadingStatsService>(
      () => _i1072.ReadingStatsService(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i1052.BookmarkRepository>(
      () => _i565.RustBookmarkRepository(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i134.BookRepository>(
      () => _i682.RustBookRepository(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i563.AuthViewModel>(
      () => _i563.AuthViewModel(gh<_i878.AuthRepository>()),
    );
    gh.lazySingletonAsync<_i499.SyncRepository>(
      () async => _i456.SyncService(await getAsync<_i772.FileStorage>()),
    );
    gh.factory<_i537.ReaderRepository>(
      () => _i1054.RustReaderRepository(gh<_i169.RustStorageService>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i460.SharedPreferences>()),
    );
    gh.factoryAsync<_i988.SyncViewModel>(
      () async => _i988.SyncViewModel(await getAsync<_i499.SyncRepository>()),
    );
    gh.factory<_i601.FontDownloadService>(
      () => _i601.FontDownloadService(
        gh<_i361.Dio>(),
        gh<_i601.CustomFontService>(),
      ),
    );
    gh.factory<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(gh<_i134.BookRepository>()),
    );
    gh.factory<_i377.BookshelfService>(
      () => _i377.BookshelfService(
        gh<_i134.BookRepository>(),
        gh<_i821.ChapterRepository>(),
        gh<_i1052.BookmarkRepository>(),
      ),
    );
    gh.factory<_i335.ReaderViewModel>(
      () => _i335.ReaderViewModel(
        gh<_i537.ReaderRepository>(),
        gh<_i849.ReaderConfig>(),
        gh<_i817.ChapterContentService>(),
        gh<_i189.ReadingProgressService>(),
        gh<_i377.BookshelfService>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}
