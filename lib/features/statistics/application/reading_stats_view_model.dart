import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 统计时段枚举
enum StatisticsPeriod { today, week, month, year }

/// 阅读统计 ViewModel。
///
/// 管理阅读统计、每日记录、趋势数据和生词统计的加载与筛选。
class ReadingStatsViewModel {
  /// 全局阅读统计
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  /// 近 N 天阅读记录
  final dailyRecords = asyncSignal<List<ReadingStats>>(AsyncState.loading());

  final vocabStats = signal(
    const VocabStats(
      totalWords: 0,
      unstartedCount: 0,
      learningCount: 0,
      masteredCount: 0,
      ignoredCount: 0,
    ),
  );

  /// 按时段加载统计数据（全局统计、每日阅读记录、生词统计）。
  Future<void> loadData({
    required StatisticsPeriod period,
    required int goalMinutes,
  }) async {
    final days = switch (period) {
      StatisticsPeriod.today => 1,
      StatisticsPeriod.week => 7,
      StatisticsPeriod.month => 30,
      StatisticsPeriod.year => 365,
    };
    // 全局统计
    try {
      final gs = await stats_api.getGlobalReadingStats();
      globalStats.value = AsyncState<GlobalStats?>.data(gs);
    } catch (e) {
      globalStats.value = AsyncState<GlobalStats?>.error(e);
    }
    // 每日阅读 + 生词统计
    try {
      dailyRecords.value = AsyncState<List<ReadingStats>>.loading();
      final results = await Future.wait([
        stats_api.getReadingStatsByDaysWithFill(days: days),
        vocab_api.getVocabularyStats(),
      ]);
      dailyRecords.value = AsyncState<List<ReadingStats>>.data(
        results[0] as List<ReadingStats>,
      );
      vocabStats.value = results[1] as VocabStats;
    } catch (e) {
      dailyRecords.value = AsyncState<List<ReadingStats>>.error(e);
    }
  }

  void dispose() {
    globalStats.dispose();
    dailyRecords.dispose();
  }
}
