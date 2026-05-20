import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class HomeViewModel {
  final RustStorageService _storage;

  final books = asyncSignal<List<Book>>(AsyncState.loading());
  final recentBooks = signal<List<Book>>([]);
  final stats = asyncSignal<GlobalStats?>(AsyncState.loading());

  HomeViewModel(this._storage);

  Future<void> loadData() async {
    try {
      final results = await Future.wait([
        _storage.getRecentlyReadBooks(4),
        _storage.getGlobalReadingStats(),
      ]);
      final bookList = results[0] as List<Book>;
      final globalStats = results[1] as GlobalStats?;
      books.value = AsyncState.data(bookList);
      recentBooks.value = bookList;
      stats.value = AsyncState.data(globalStats);
    } catch (e) {
      books.value = AsyncState.error(e);
      stats.value = AsyncState.error(e);
    }
  }

  Future<void> refresh() async {
    books.value = AsyncState.loading();
    stats.value = AsyncState.loading();
    await loadData();
  }
}
