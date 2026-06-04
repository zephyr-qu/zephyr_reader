import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReadingSessionsViewModel {
  final sessions = signal<List<ReadingSession>>([]);
  final bookCache = signal<Map<String, Book>>({});
  final loaded = signal(false);
  final loading = signal(false);

  Future<void> load() async {
    loading.value = true;
    try {
      sessions.value = await session_api.listSessionsByRecent(
        limit: BigInt.from(100),
      );
      // 只加载会话涉及到的书籍
      final bookIds = sessions.value.map((s) => s.bookId).toSet().toList();
      final books = await Future.wait(
        bookIds.map((id) => book_api.getBook(bookId: id)),
      );
      bookCache.value = {
        for (final b in books)
          if (b != null) b.bookId: b,
      };
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
}
