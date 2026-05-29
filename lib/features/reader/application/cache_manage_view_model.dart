import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class CacheManageViewModel {
  final ReaderRepository repo;
  final String? bookId;

  final books = signal<List<Book>>([]);
  final progressList = signal<List<BookWithProgress>>([]);
  final loaded = signal(false);

  CacheManageViewModel({required this.repo, this.bookId}) {
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([
        book_api.listBooks(),
        progress_api.listAllProgresses(),
      ]);
      books.value = results[0] as List<Book>;
      progressList.value = results[1] as List<BookWithProgress>;
      loaded.value = true;
    } catch (_) {
      loaded.value = true;
    }
  }

  Future<void> clearProgress(String bookId) async {
    await progress_api.clearProgress(bookId: bookId);
    await load();
  }

  void clearAllCache() {
    repo.clearAllCache();
  }

  void clearProgressCache() {
    repo.clearProgressCache();
  }

  void dispose() {
    books.dispose();
    progressList.dispose();
    loaded.dispose();
  }
}
