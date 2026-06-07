import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 首页最近阅读列表最大条目数
final _recentBookLimit = 4;

/// 首页 ViewModel。
///
/// 管理最近阅读书籍列表和阅读趋势数据的异步加载状态。
class HomeViewModel {
  final recentBooks = asyncSignal<List<Book>>(AsyncState.loading());
  final dailyRecords = asyncSignal<List<ReadingStats>>(AsyncState.loading());

  /// 分别加载两个数据源，避免一个 API 失败连带另一个。
  Future<void> loadData() async {
    await Future.wait([
      recentBooks.loadAsync(
        () => book_api.listRecentlyOpenedBooks(limit: _recentBookLimit),
        label: '最近阅读',
      ),
      dailyRecords.loadAsync(
        () => stats_api.getReadingStatsByDaysWithFill(days: 7),
        label: '阅读趋势',
      ),
    ]);
  }
}
