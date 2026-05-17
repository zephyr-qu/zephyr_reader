library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReadingStatsPage extends StatefulWidget {
  const ReadingStatsPage({super.key});

  @override
  State<ReadingStatsPage> createState() => _ReadingStatsPageState();
}

class _ReadingStatsPageState extends State<ReadingStatsPage> {
  final _statsService = getIt<ReadingStatsService>();
  List<ReadingStats> _dailyRecords = [];
  GlobalStats? _globalStats;
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
    final theme = Theme.of(context);
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    final totalMinutes = _globalStats != null
        ? '${(_globalStats!.totalReadingTimeSeconds ~/ 60)} 分钟'
        : '加载中…';
    final totalChars = _globalStats != null
        ? '${(_globalStats!.totalCharactersRead ~/ 10000)} 万字'
        : '加载中…';
    final readingDays = _globalStats != null
        ? '${_globalStats!.consecutiveReadingDays} 天'
        : '加载中…';

    final avgSpeed = _globalStats != null
        ? '${_globalStats!.averageReadingSpeed.toStringAsFixed(0)} 字/分钟'
        : '加载中…';
    final consecutiveDays = _globalStats != null
        ? '${_globalStats!.consecutiveReadingDays} 天'
        : '加载中…';

    return Scaffold(
      appBar: AppBar(title: const Text('阅读统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
        children: [
          const SizedBox(height: 8),
          const Text('本周总览',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 8),
          Row(
            children: [
              _statItem('阅读时长', totalMinutes),
              const SizedBox(width: 48),
              _statItem('阅读字数', totalChars),
              const SizedBox(width: 48),
              _statItem('阅读天数', readingDays),
            ],
          ),
          const SizedBox(height: 32),
          const Text('本周阅读时长',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 16),
          if (!_loaded)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _dailyRecords.isEmpty
                      ? 10
                      : _dailyRecords.map((r) => r.readingTimeSeconds / 60.0).reduce((a, b) => a > b ? a : b) + 15,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                        BarTooltipItem('${rod.toY.toStringAsFixed(0)}分钟',
                          TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= weekdays.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(weekdays[value.toInt()],
                              style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: weekdays.asMap().entries.map((entry) {
                    final minutes = entry.key < _dailyRecords.length
                        ? _dailyRecords[entry.key].readingTimeSeconds / 60.0
                        : 0.0;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: minutes,
                          color: theme.colorScheme.primary,
                          width: 8,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Text('阅读习惯',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          _habitRow('平均阅读速度', avgSpeed),
          _habitRow('连续阅读天数', consecutiveDays),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: DesignTokens.primary, letterSpacing: -0.3),
        ),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
        ),
      ],
    );
  }

  Widget _habitRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(label,
            style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary),
          ),
          const Spacer(),
          Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: DesignTokens.primary),
          ),
        ],
      ),
    );
  }
}
