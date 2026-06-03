import 'package:signals_flutter/signals_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class ReadingSessionsViewModel {
  final sessions = signal<List<ReadingSession>>([]);
  final bookCache = signal<Map<String, Book>>({});
  final loaded = signal(false);
  final loading = signal(false);

  ReadingSessionsViewModel() {
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final results = await Future.wait([
        session_api.listSessionsByRecent(limit: BigInt.from(100)),
        session_api.listSessionsByBook(bookId: '', limit: BigInt.from(1)),
      ]);
      sessions.value = results[0];
      bookCache.value = {for (final b in results[1] as List<Book>) b.bookId: b};
      loaded.value = true;
    } catch (_) {
      loaded.value = true;
    }
    loading.value = false;
  }

  Future<void> deleteSessionsByBook(String bookId) async {
    await session_api.clearSessionsByBook(bookId: bookId);
    await load();
  }

  void dispose() {
    sessions.dispose();
    bookCache.dispose();
    loaded.dispose();
    loading.dispose();
  }
}
