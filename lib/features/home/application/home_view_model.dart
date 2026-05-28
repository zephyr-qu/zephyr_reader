import 'package:injectable/injectable.dart';
import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class HomeViewModel {
  final recentBooks = signal<AsyncState<List<Book>>>(AsyncState.loading());
  final dailyRecords = signal<AsyncState<List<ReadingStats>>>(
    AsyncState.loading(),
  );

  final _refreshTrigger = signal(0);

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
    recentBooks.value = AsyncState.loading();
    dailyRecords.value = AsyncState.loading();

    try {
      final results = await Future.wait([
        book_api.listRecentlyOpenedBooks(limit: BigInt.from(4)),
        stats_api.getReadingStatsByDaysWithFill(days: 7),
      ]);

      recentBooks.value = AsyncState.data(results[0] as List<Book>);
      dailyRecords.value = AsyncState.data(results[1] as List<ReadingStats>);
    } catch (e) {
      Logging.error(e.toString());
      recentBooks.value = AsyncState.error(e, StackTrace.current);
      dailyRecords.value = AsyncState.error(e, StackTrace.current);
    }
  }

  Future<void> refresh() async {
    _refreshTrigger.value++;
    await loadData();
  }

  void dispose() {
    recentBooks.dispose();
    dailyRecords.dispose();
    _refreshTrigger.dispose();
  }
}
