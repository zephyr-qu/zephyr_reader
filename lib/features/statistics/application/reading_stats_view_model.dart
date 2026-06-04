import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 统计时段枚举
enum StatisticsPeriod { today, week, month, year }

class ReadingStatsViewModel {
  /// 全局阅读统计
  final globalStats = signal<GlobalStats?>(null);

  /// 近 N 天阅读记录
  final dailyRecords = signal<List<ReadingStats>>([]);

  /// 每日阅读分钟数（图表数据，派生自 dailyRecords）
  late final dailyMinutes = computed(
    () => dailyRecords.value
        .map((r) => r.readingTimeSeconds.toInt() / 60.0)
        .toList(),
  );

  /// 当前选中时段
  final selectedPeriod = signal<StatisticsPeriod>(StatisticsPeriod.month);

  /// 每日阅读目标（分钟）
  final goalMinutes = signal(60);

  final vocabUnstarted = signal(0);
  final vocabLearning = signal(0);
  final vocabMastered = signal(0);
  final vocabIgnored = signal(0);
  final loaded = signal(false);

  /// 按时段加载统计数据
  Future<void> loadData({StatisticsPeriod? period}) async {
    if (period != null) selectedPeriod.value = period;
    final days = switch (selectedPeriod.value) {
      StatisticsPeriod.today => 1,
      StatisticsPeriod.week => 7,
      StatisticsPeriod.month => 30,
      StatisticsPeriod.year => 365,
    };
    // 全局统计不依赖时段，仅首次加载
    if (globalStats.value == null) {
      final gs = await safeLoad(
        () => stats_api.getGlobalReadingStats(),
        label: '加载全局统计',
      );
      if (gs != null) globalStats.value = gs;
    }
    final results = await safeLoad(
      () => Future.wait([
        stats_api.getReadingStatsByDaysWithFill(days: days),
        vocab_api.getVocabularyStats(),
      ]),
      label: '加载统计数据',
    );
    if (results != null) {
      dailyRecords.value = results[0] as List<ReadingStats>;
      final vs = results[1] as VocabStats;
      vocabUnstarted.value = vs.unstartedCount.toInt();
      vocabLearning.value = vs.learningCount.toInt();
      vocabMastered.value = vs.masteredCount.toInt();
      vocabIgnored.value = vs.ignoredCount.toInt();
    }
    loaded.value = true;
  }
}
