import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'service_locator.config.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/book_repository_impl.dart' as book_repo_impl;
import 'package:zephyr_reader/features/bookshelf/data/repositories/chapter_repository_impl.dart' as chapter_repo_impl;
import 'package:zephyr_reader/features/bookshelf/data/repositories/bookmark_repository_impl.dart' as bookmark_repo_impl;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart' as book_repo;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/chapter_repository.dart' as chapter_repo;
import 'package:zephyr_reader/features/bookshelf/domain/repositories/bookmark_repository.dart' as bookmark_repo;
import 'package:zephyr_reader/features/reader/data/repositories/reader_repository_impl.dart' as reader_repo_impl;
import 'package:zephyr_reader/features/reader/domain/repositories/reader_repository.dart' as reader_repo;

final getIt = GetIt.instance;

@InjectableInit()
Future<void> configureDependencies() async {
  await getIt.init();

  // 手动注册 Repository
  getIt.registerLazySingleton<book_repo.BookRepository>(
    () => getIt.get<book_repo_impl.BookRepositoryImpl>(),
  );
  getIt.registerLazySingleton<chapter_repo.ChapterRepository>(
    () => getIt.get<chapter_repo_impl.ChapterRepositoryImpl>(),
  );
  getIt.registerLazySingleton<bookmark_repo.BookmarkRepository>(
    () => getIt.get<bookmark_repo_impl.BookmarkRepositoryImpl>(),
  );
  getIt.registerLazySingletonAsync<reader_repo.ReaderRepository>(
    () async => getIt.get<reader_repo_impl.ReaderRepositoryImpl>(),
  );
}
