import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 缓存管理 ViewModel。
///
/// 管理书籍列表、排版缓存和搜索索引信息的加载与清理。
class CacheManageViewModel {
  final books = asyncSignal<List<Book>>(AsyncState.loading());
  final progressList = asyncSignal<List<BookWithProgress>>(
    AsyncState.loading(),
  );
  final searchIndexStats = signal<AsyncState<IndexStats>>(AsyncState.loading());

  /// 加载书籍列表、阅读进度和搜索索引统计。
  Future<void> load() async {
    batch(() {
      books.value = AsyncState.loading();
      progressList.value = AsyncState.loading();
      searchIndexStats.value = AsyncState.loading();
    });
    try {
      final results = await Future.wait([
        book_api.listBooks(),
        progress_api.listAllProgresses(),
        search_api.getIndexStats(),
      ]);
      batch(() {
        books.value = AsyncState.data(results[0] as List<Book>);
        progressList.value = AsyncState.data(
          results[1] as List<BookWithProgress>,
        );
        searchIndexStats.value = AsyncState.data(results[2] as IndexStats);
      });
    } catch (e) {
      batch(() {
        books.value = AsyncState.error(e);
        progressList.value = AsyncState.error(e);
        searchIndexStats.value = AsyncState.error(e);
      });
    }
  }

  /// 清除指定书籍的阅读进度后仅重载进度列表。
  Future<void> clearProgress(String bookId) async {
    try {
      await progress_api.clearProgress(bookId: bookId);
      final updated = await progress_api.listAllProgresses();
      progressList.value = AsyncState.data(updated);
    } catch (e) {
      progressList.value = AsyncState.error(e);
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    books.dispose();
    progressList.dispose();
    searchIndexStats.dispose();
  }
}
