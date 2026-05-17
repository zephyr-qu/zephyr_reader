import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final _statsService = getIt<ReadingStatsService>();
  final _storage = getIt<RustStorageService>();
  List<ReadingStats> _dailyRecords = [];
  GlobalStats? _globalStats;
  List<BookCategory> _categories = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _statsService.getDailyRecords(days: 7),
        _statsService.getGlobalStats(),
        _storage.getAllCategories(),
      ]);
      if (mounted) {
        setState(() {
          _dailyRecords = results[0] as List<ReadingStats>;
          _globalStats = results[1] as GlobalStats?;
          _categories = results[2] as List<BookCategory>;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final chartMinutes = List<double>.generate(7, (i) {
      if (i < _dailyRecords.length) {
        return _dailyRecords[i].readingTimeSeconds / 60.0;
      }
      return 0;
    });

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              _overviewItem('${_globalStats?.consecutiveReadingDays ?? 0}', '天'),
              const SizedBox(width: 48),
              _overviewItem('${(_globalStats?.totalReadingTimeSeconds ?? 0) ~/ 3600}', '小时'),
              const SizedBox(width: 48),
              _overviewItem('${_globalStats?.booksCompletedCount ?? 0}', '本'),
            ],
          ),
          const SizedBox(height: 40),
          const Text('本周阅读',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 16),
          if (!_loaded)
            const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()))
          else
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMinutes.reduce((a, b) => a > b ? a : b) + 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toStringAsFixed(0)} 分钟',
                          TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= weekdays.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(weekdays[idx],
                              style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: weekdays.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.key < chartMinutes.length ? chartMinutes[entry.key] : 0,
                          color: theme.colorScheme.primary,
                          width: 6,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2),
                            topRight: Radius.circular(2),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 40),
          const Text('分类统计',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 12),
          if (!_loaded)
            const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          else if (_categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('暂无分类', style: TextStyle(color: DesignTokens.textSecondary)),
            )
          else
            ..._categories.map((c) => _categoryRow(c.name, 0)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push(RoutePaths.readingStats),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
              ),
              child: Row(
                children: [
                  const Text('查看每日统计详情',
                    style: TextStyle(fontSize: 14, color: DesignTokens.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 16, color: DesignTokens.primary.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _overviewItem(String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700,
                color: DesignTokens.primary, letterSpacing: -0.5),
            ),
            const SizedBox(width: 4),
            Text(unit,
              style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _categoryRow(String name, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 4,
            decoration: const BoxDecoration(
              color: DesignTokens.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name,
            style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary),
          )),
        ],
      ),
    );
  }
}
