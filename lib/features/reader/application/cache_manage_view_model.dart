import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class CacheManageViewModel {
  final ReaderRepository repo;
  final String? bookId;

  final books = asyncSignal<List<Book>>(AsyncState.loading());
  final progressList = asyncSignal<List<BookWithProgress>>(
    AsyncState.loading(),
  );

  CacheManageViewModel({required this.repo, this.bookId});

  /// 加载书籍列表和阅读进度列表。
  Future<void> load() async {
    batch(() {
      books.value = AsyncState.loading();
      progressList.value = AsyncState.loading();
    });
    try {
      final results = await Future.wait([
        book_api.listBooks(),
        progress_api.listAllProgresses(),
      ]);
      batch(() {
        books.value = AsyncState.data(results[0] as List<Book>);
        progressList.value = AsyncState.data(
          results[1] as List<BookWithProgress>,
        );
      });
    } catch (e) {
      batch(() {
        books.value = AsyncState.error(e);
        progressList.value = AsyncState.error(e);
      });
    }
  }

  /// 清除指定书籍的阅读进度。
  Future<void> clearProgress(String bookId) async {
    await progress_api.clearProgress(bookId: bookId);
    await load();
  }

  /// 清除 Rust 仓库层的阅读进度缓存。
  void clearProgressCache() {
    repo.clearProgressCache();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    books.dispose();
    progressList.dispose();
  }
}
