import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
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
  List<ReadingStats> _dailyRecords = [];
  GlobalStats? _globalStats;
  bool _loaded = false;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _statsService.getDailyRecords(days: 30),
        _statsService.getGlobalStats(),
      ]);
      if (mounted) {
        setState(() {
          _dailyRecords = results[0] as List<ReadingStats>;
          _globalStats = results[1] as GlobalStats?;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '年度阅览报告',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildOverview(cs),
                const SizedBox(height: 32),
                _buildHeatmap(cs),
                const SizedBox(height: 32),
                _buildTrend(cs),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  Widget _buildOverview(ColorScheme cs) {
    final stats = _globalStats;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '阅读概览',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    cs,
                    '${stats?.consecutiveReadingDays ?? 0}',
                    '连续天数',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    cs,
                    '${(stats?.totalReadingTimeSeconds ?? 0) ~/ 3600}',
                    '阅读小时',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    cs,
                    '${stats?.booksCompletedCount ?? 0}',
                    '读完书籍',
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _statCard(ColorScheme cs, String value, String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: double.tryParse(value) ?? 0),
            duration: 1200.ms,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final display = value.contains('.')
                  ? v.toStringAsFixed(1)
                  : v.toInt().toString();
              return Text(
                display,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(ColorScheme cs) {
    final today = DateTime.now();
    final records = _dailyRecords;
    final recordMap = <String, int>{};
    for (final r in records) {
      recordMap[r.date] = r.readingTimeSeconds ~/ 60;
    }
    final cells = <List<int>>[];
    for (var w = 0; w < 4; w++) {
      final week = <int>[];
      for (var d = 0; d < 7; d++) {
        final date = today.subtract(Duration(days: (3 - w) * 7 + (6 - d)));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        week.add(recordMap[key] ?? 0);
      }
      cells.add(week);
    }
    final activeDays = records.where((r) => r.readingTimeSeconds > 0).length;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Text(
                    '阅读足迹',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '近28天 · $activeDays 天活跃',
                      style: const TextStyle(
                        fontSize: 10,
                        color: DesignTokens.warmAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if ((_globalStats?.consecutiveReadingDays ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.fire,
                            size: 18,
                            color: DesignTokens.warmAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '已连续阅读 ${_globalStats!.consecutiveReadingDays} 天',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: DesignTokens.warmAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _stampLegend(cs, '少', _stampColors(cs)[0]),
                      ..._stampColors(
                        cs,
                      ).skip(1).map((c) => _stampLegend(cs, '', c)),
                      _stampLegend(cs, '多', _stampColors(cs).last),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: _weekdayLabels
                            .map(
                              (l) => Container(
                                height: 22,
                                alignment: Alignment.center,
                                child: Text(
                                  l,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: List.generate(
                            4,
                            (w) => Expanded(
                              child: Column(
                                children: List.generate(7, (d) {
                                  final mins = cells[w][d];
                                  return Container(
                                    margin: const EdgeInsets.all(1.5),
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _stampColorFor(cs, mins),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  List<Color> _stampColors(ColorScheme cs) => [
    cs.primary.withValues(alpha: 0.12),
    cs.primary.withValues(alpha: 0.25),
    cs.primary.withValues(alpha: 0.45),
    cs.primary.withValues(alpha: 0.7),
    cs.primary,
  ];

  Color _stampColorFor(ColorScheme cs, int minutes) {
    final colors = _stampColors(cs);
    if (minutes == 0) return Colors.transparent;
    if (minutes < 15) return colors[0];
    if (minutes < 30) return colors[1];
    if (minutes < 60) return colors[2];
    if (minutes < 90) return colors[3];
    return colors[4];
  }

  Widget _stampLegend(ColorScheme cs, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (label.isNotEmpty) const SizedBox(width: 3),
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrend(ColorScheme cs) {
    final records = _dailyRecords;
    if (records.isEmpty) return const SizedBox.shrink();
    final minutes = records.map((r) => r.readingTimeSeconds / 60.0).toList();
    final maxY = minutes
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, double.infinity);
    final days = records.map((r) {
      final parts = r.date.split('-');
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    }).toList();

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '阅读节奏',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY + 10,
                    barTouchData: const BarTouchData(enabled: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 16,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) {
                              return const SizedBox.shrink();
                            }
                            if (idx % 5 != 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[idx],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(minutes.length, (i) {
                      final isToday = i == minutes.length - 1;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: minutes[i].clamp(0, double.infinity),
                            color: isToday
                                ? DesignTokens.warmAccent
                                : cs.primary,
                            width: 6,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }
}
