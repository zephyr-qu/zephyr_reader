library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReadingStatsPage extends HookWidget {
  final ReadingStatsViewModel vm;

  const ReadingStatsPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    // Load on mount
    useEffect(() {
      vm.loadDashboard();
      return null;
    }, []);

    // Bind VM signals
    final dashboardLoading = useSignalValue<bool, Signal<bool>>(
      vm.dashboardLoading,
    );
    final dashboardError = useSignalValue<String?, Signal<String?>>(
      vm.dashboardError,
    );
    final globalStats = useSignalValue<GlobalStats?, Signal<GlobalStats?>>(
      vm.globalStats,
    );
    final dailyMinutes = useSignalValue<List<double>, ReadonlySignal<List<double>>>(
      vm.dailyMinutes,
    );

    final totalMinutes = globalStats != null
        ? '${globalStats.totalReadingTimeSeconds ~/ 60} 分钟'
        : '加载中…';
    final totalChars = globalStats != null
        ? '${globalStats.totalCharactersRead ~/ 10000} 万字'
        : '加载中…';
    final readingDays = globalStats != null
        ? '${globalStats.consecutiveReadingDays} 天'
        : '加载中…';
    final avgSpeed = globalStats != null
        ? '${globalStats.averageReadingSpeed.toStringAsFixed(0)} 字/分钟'
        : '加载中…';
    final consecutiveDays = globalStats != null
        ? '${globalStats.consecutiveReadingDays} 天'
        : '加载中…';

    return Scaffold(
      appBar: AppBar(title: const Text('阅读统计')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SizedBox(height: 8),
            if (dashboardError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.warningCircle,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dashboardError,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: () => vm.loadDashboard(),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              '本周总览',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const Divider(height: 12),
            const SizedBox(height: 8),
            Row(
              children: [
                _statItem('阅读时长', totalMinutes, theme),
                const SizedBox(width: 48),
                _statItem('阅读字数', totalChars, theme),
                const SizedBox(width: 48),
                _statItem('阅读天数', readingDays, theme),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              '本周阅读时长',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const Divider(height: 12),
            const SizedBox(height: 16),
            if (dashboardLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: dailyMinutes.isEmpty
                        ? 10
                        : dailyMinutes.reduce((a, b) => a > b ? a : b) + 15,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                          '${rod.toY.toStringAsFixed(0)}分钟',
                          TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= weekdays.length) {
                              return const SizedBox();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                weekdays[value.toInt()],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        strokeWidth: 0.5,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weekdays.asMap().entries.map((entry) {
                      final minutes = entry.key < dailyMinutes.length
                          ? dailyMinutes[entry.key]
                          : 0.0;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: minutes,
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                theme.colorScheme.primary,
                                DesignTokens.warmAccent,
                              ],
                            ),
                            width: 8,
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
            const SizedBox(height: 32),
            Text(
              '阅读习惯',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
            const Divider(height: 12),
            _habitRow('平均阅读速度', avgSpeed, theme),
            _habitRow('连续阅读天数', consecutiveDays, theme),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _habitRow(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
