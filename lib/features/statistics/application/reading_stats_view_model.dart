import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/domain/stats/models.dart';


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

  /// 全局统计已加载（与周期无关，仅需加载一次）
  bool _globalLoaded = false;
  /// 加载该时段的每日记录；全局统计仅首载（与周期无关）。
  Future<void> loadData({required StatisticsPeriod period}) async {
    await _loadGlobalOnce();
    await _loadDaily(period);
  }

  Future<void> _loadGlobalOnce() async {
    if (_globalLoaded) return;
    _globalLoaded = true;
    try {
      final gs = await stats_api.getGlobalReadingStats();
      globalStats.value = AsyncState<GlobalStats?>.data(gs);
    } catch (e) {
      globalStats.value = AsyncState<GlobalStats?>.error(e);
    }
  }

  Future<void> _loadDaily(StatisticsPeriod period) async {
    final days = switch (period) {
      StatisticsPeriod.today => 1,
      StatisticsPeriod.week => 7,
      StatisticsPeriod.month => 30,
      StatisticsPeriod.year => 365,
    };
    try {
      dailyRecords.value = AsyncState<List<ReadingStats>>.loading();
      dailyRecords.value = AsyncState<List<ReadingStats>>.data(
        await stats_api.getReadingStatsByDaysWithFill(days: days),
      );
    } catch (e) {
      dailyRecords.value = AsyncState<List<ReadingStats>>.error(e);
    }
  }

  void dispose() {
    globalStats.dispose();
    dailyRecords.dispose();
  }
}
