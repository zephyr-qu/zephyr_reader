import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class HomeViewModel {
  final recentBooks = signal<AsyncState<List<Book>>>(AsyncState.loading());
  final dailyRecords = signal<AsyncState<List<ReadingStats>>>(
    AsyncState.loading(),
  );

  late final isLoading = computed(
    () => recentBooks.value.isLoading || dailyRecords.value.isLoading,
  );

  late final hasError = computed(
    () => recentBooks.value.hasError || dailyRecords.value.hasError,
  );

  HomeViewModel() {
    loadData();
  }

  Future<void> loadData() async {
    final results = await safeLoad(
      () => Future.wait([
        book_api.listRecentlyOpenedBooks(limit: BigInt.from(4)),
        stats_api.getReadingStatsByDaysWithFill(days: 7),
      ]),
      label: '加载首页数据',
    );
    if (results != null) {
      recentBooks.value = AsyncState.data(results[0] as List<Book>);
      dailyRecords.value = AsyncState.data(results[1] as List<ReadingStats>);
    } else {
      final err = AsyncState<List<Book>>.error('加载失败');
      recentBooks.value = err;
      dailyRecords.value = AsyncState<List<ReadingStats>>.error('加载失败');
    }
  }

  Future<void> refresh() async {
    await loadData();
  }
}
