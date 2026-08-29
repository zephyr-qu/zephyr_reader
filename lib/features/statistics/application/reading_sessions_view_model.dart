import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/api/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/sessions/models.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/stats/models.dart';


/// 阅读会话列表 ViewModel。
///
/// 加载历史阅读会话记录及其关联的书籍信息。
class ReadingSessionsViewModel {
  final sessions = asyncSignal<List<ReadingSession>>(AsyncState.loading());
  final bookCache = signal<Map<String, Book>>({});

  /// 全局统计（总时长的权威来源，与统计页/详情页一致）
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());
  /// 加载最近 100 条阅读会话、关联书籍与全局统计。
  Future<void> load() async {
    sessions.value = AsyncState.loading();
    try {
      // 全局统计与会话列表并行拉取（时长用权威聚合，列表本身保持最近一批）
      final results = await Future.wait<Object>([
        session_api.listSessionsByRecent(limit: 100),
        stats_api.getGlobalReadingStats(),
      ]);
      final data = results[0] as List<ReadingSession>;
      final gs = results[1] as GlobalStats?;
      globalStats.value = AsyncState<GlobalStats?>.data(gs);

      // 只加载会话涉及到的书籍（失败不影响会话展示）
      try {
        final bookIds = data.map((s) => s.bookId).toSet().toList();
        final books = await Future.wait(
          bookIds.map((id) => book_api.getBook(bookId: id)),
        );
        bookCache.value = {for (final b in books) b!.bookId: b};
      } catch (e, stack) {
        Logging.error('加载书籍缓存失败', exception: e, stackTrace: stack);
        bookCache.value = {};
      }
      sessions.value = AsyncState.data(data);
    } catch (e, stack) {
      Logging.error('加载阅读会话失败', exception: e, stackTrace: stack);
      sessions.value = AsyncState.error(e);
    }
  }

  /// 删除指定书籍的所有阅读会话并重新加载。
  Future<void> deleteSessionsByBook(String bookId) async {
    try {
      await session_api.deleteSessionsByBook(bookId: bookId);
      await load();
    } catch (e, stack) {
      Logging.error('删除阅读会话失败', exception: e, stackTrace: stack);
      sessions.value = AsyncState.error(e);
    }
  }

  void dispose() {
    sessions.dispose();
    globalStats.dispose();
    bookCache.dispose();
  }
}
