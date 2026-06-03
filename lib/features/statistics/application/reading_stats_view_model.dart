import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 统计时段枚举
enum StatisticsPeriod { today, week, month, year }

@LazySingleton()
class ReadingStatsViewModel {
  // ==================== 共享统计状态 ====================

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

  // ==================== Dashboard 状态（阅读统计页） ====================

  final dashboardLoading = signal<bool>(false);
  final dashboardError = signal<String?>(null);

  /// 加载 Dashboard 数据
  Future<void> loadDashboard() async {
    dashboardLoading.value = true;
    dashboardError.value = null;
    final results = await safeLoad(
      () => Future.wait([
        stats_api.getReadingStatsByDaysWithFill(days: 7),
        stats_api.getGlobalReadingStats(),
      ]),
      label: '加载统计面板',
    );
    if (results != null) {
      dailyRecords.value = results[0] as List<ReadingStats>;
      globalStats.value = results[1] as GlobalStats?;
    }
    dashboardLoading.value = false;
  }

  // ==================== 时段统计状态（统计页） ====================

  final selectedPeriod = signal<StatisticsPeriod>(StatisticsPeriod.month);
  final vocabNew = signal(0);
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
    final results = await safeLoad(
      () => Future.wait([
        stats_api.getGlobalReadingStats(),
        stats_api.getReadingStatsByDaysWithFill(days: days),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.new_),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.learning),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.mastered),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.ignored),
      ]),
      label: '加载统计数据',
    );
    if (results != null) {
      globalStats.value = results[0] as GlobalStats;
      dailyRecords.value = results[1] as List<ReadingStats>;
      vocabNew.value = (results[2] as List<Vocab>).length;
      vocabLearning.value = (results[3] as List<Vocab>).length;
      vocabMastered.value = (results[4] as List<Vocab>).length;
      vocabIgnored.value = (results[5] as List<Vocab>).length;
    }
    loaded.value = true;
  }

  void dispose() {
    globalStats.dispose();
    dailyRecords.dispose();
    selectedPeriod.dispose();
    vocabNew.dispose();
    vocabLearning.dispose();
    vocabMastered.dispose();
    vocabIgnored.dispose();
    loaded.dispose();
  }
}
