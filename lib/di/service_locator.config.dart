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
import 'package:zephyr_reader/core/local/rust_bilingual_service.dart' as _i448;
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
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart'
    as _i790;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart'
    as _i682;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_bookmark_repository.dart'
    as _i565;
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_chapter_repository.dart'
    as _i454;
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart'
    as _i335;
import 'package:zephyr_reader/features/reader/data/custom_font_service.dart'
    as _i601;
import 'package:zephyr_reader/features/reader/data/dictionary_service.dart'
    as _i576;
import 'package:zephyr_reader/features/reader/data/note_repository.dart'
    as _i820;
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart'
    as _i1054;
import 'package:zephyr_reader/features/reader/data/tts_service.dart' as _i989;
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart'
    as _i880;
import 'package:zephyr_reader/features/search/application/search_view_model.dart'
    as _i1;
import 'package:zephyr_reader/features/search/application/services/full_text_search_service.dart'
    as _i425;
import 'package:zephyr_reader/features/search/data/search_service.dart'
    as _i584;
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart'
    as _i1072;
import 'package:zephyr_reader/features/sync/application/sync_view_model.dart'
    as _i988;
import 'package:zephyr_reader/features/sync/data/sync_service.dart' as _i456;
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart'
    as _i104;
import 'package:zephyr_reader/features/vocabulary/data/vocabulary_service.dart'
    as _i435;

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
    gh.factory<_i576.DictionaryService>(() => _i576.DictionaryService());
    gh.factory<_i435.VocabularyService>(() => _i435.VocabularyService());
    gh.singleton<_i169.RustStorageService>(() => _i169.RustStorageService());
    gh.lazySingletonAsync<_i772.FileStorage>(() {
      final i = _i772.FileStorage();
      return i.init().then((_) => i);
    });
    gh.lazySingleton<_i448.RustBilingualService>(
      () => _i448.RustBilingualService(),
    );
    gh.lazySingleton<_i607.RustCoreService>(() => _i607.RustCoreService());
    gh.lazySingleton<_i14.RustCoverService>(() => _i14.RustCoverService());
    gh.lazySingleton<_i633.RustEpubService>(() => _i633.RustEpubService());
    gh.lazySingleton<_i148.RustSearchService>(() => _i148.RustSearchService());
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio);
    gh.lazySingleton<_i989.TtsService>(() => _i989.TtsService());
    gh.lazySingleton<_i880.VocabularyMarkerService>(
      () => _i880.VocabularyMarkerService(),
    );
    gh.lazySingleton<_i584.SearchRepository>(() => _i584.SearchRepository());
    gh.singleton<_i425.FullTextSearchService>(
      () => _i425.FullTextSearchService(gh<_i148.RustSearchService>()),
    );
    gh.factory<_i1054.ReaderRepository>(
      () => _i1054.ReaderRepository(
        gh<_i169.RustStorageService>(),
        gh<_i633.RustEpubService>(),
        gh<_i607.RustCoreService>(),
      ),
    );
    gh.factory<_i569.ArticleApi>(() => _i569.ArticleApi(gh<_i361.Dio>()));
    gh.factory<_i601.FontRepository>(
      () => _i601.FontRepository(gh<_i460.SharedPreferences>()),
    );
    gh.factory<_i565.BookmarkRepository>(
      () => _i565.BookmarkRepository(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i454.ChapterRepository>(
      () => _i454.ChapterRepository(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i820.NoteRepository>(
      () => _i820.NoteRepository(gh<_i169.RustStorageService>()),
    );
    gh.lazySingleton<_i1072.ReadingStatsService>(
      () => _i1072.ReadingStatsService(gh<_i169.RustStorageService>()),
    );
    gh.factory<_i1.SearchViewModel>(
      () => _i1.SearchViewModel(gh<_i584.SearchRepository>()),
    );
    gh.factory<_i104.VocabularyViewModel>(
      () => _i104.VocabularyViewModel(gh<_i435.VocabularyService>()),
    );
    gh.singleton<_i849.ReaderConfig>(
      () => _i849.ReaderConfig(gh<_i460.SharedPreferences>()),
    );
    gh.lazySingletonAsync<_i456.SyncRepository>(
      () async => _i456.SyncRepository(await getAsync<_i772.FileStorage>()),
    );
    gh.lazySingleton<_i582.ArticleRepository>(
      () => _i582.ArticleRepository(gh<_i569.ArticleApi>()),
    );
    gh.factoryAsync<_i988.SyncViewModel>(
      () async => _i988.SyncViewModel(await getAsync<_i456.SyncRepository>()),
    );
    gh.factory<_i682.BookRepository>(
      () => _i682.BookRepository(
        gh<_i169.RustStorageService>(),
        gh<_i454.ChapterRepository>(),
        gh<_i565.BookmarkRepository>(),
        gh<_i607.RustCoreService>(),
        gh<_i14.RustCoverService>(),
        gh<_i425.FullTextSearchService>(),
      ),
    );
    gh.factory<_i556.ArticleViewModel>(
      () => _i556.ArticleViewModel(gh<_i582.ArticleRepository>()),
    );
    gh.factory<_i335.ReaderViewModel>(
      () => _i335.ReaderViewModel(
        gh<_i1054.ReaderRepository>(),
        gh<_i849.ReaderConfig>(),
        gh<_i1072.ReadingStatsService>(),
        gh<_i820.NoteRepository>(),
        gh<_i448.RustBilingualService>(),
      ),
    );
    gh.factory<_i790.BookshelfViewModel>(
      () => _i790.BookshelfViewModel(
        gh<_i682.BookRepository>(),
        gh<_i460.SharedPreferences>(),
      ),
    );
    return this;
  }
}

class _$AppModule extends _i431.AppModule {}

class _$NetworkModule extends _i510.NetworkModule {}
