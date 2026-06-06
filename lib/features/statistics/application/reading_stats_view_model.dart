import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 统计时段枚举
enum StatisticsPeriod { today, week, month, year }

class ReadingStatsViewModel {
  /// 全局阅读统计
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  /// 近 N 天阅读记录
  final dailyRecords = asyncSignal<List<ReadingStats>>(AsyncState.loading());

  /// 每日阅读分钟数（图表数据，派生自 dailyRecords）
  // UNUSED: computed 信号已定义但没有任何页面/组件读取 .value
  late final dailyMinutes = computed(
    () =>
        dailyRecords.value.value
            ?.map((r) => r.readingTimeSeconds.toInt() / 60.0)
            .toList() ??
        [],
  );

  /// 当前选中时段
  final selectedPeriod = signal<StatisticsPeriod>(StatisticsPeriod.today);

  /// 每日阅读目标（分钟）
  final goalMinutes = signal(60);

  final vocabUnstarted = signal(0);
  final vocabLearning = signal(0);
  final vocabMastered = signal(0);
  final vocabIgnored = signal(0);

  /// 按时段加载统计数据（全局统计、每日阅读记录、生词统计）。
  Future<void> loadData({StatisticsPeriod? period}) async {
    if (period != null) selectedPeriod.value = period;
    final days = switch (selectedPeriod.value) {
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
      final vs = results[1] as VocabStats;
      vocabUnstarted.value = vs.unstartedCount.toInt();
      vocabLearning.value = vs.learningCount.toInt();
      vocabMastered.value = vs.masteredCount.toInt();
      vocabIgnored.value = vs.ignoredCount.toInt();
    } catch (e) {
      dailyRecords.value = AsyncState<List<ReadingStats>>.error(e);
    }
  }
}
