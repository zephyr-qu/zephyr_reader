import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeklyData = [35.0, 50.0, 20.0, 80.0, 45.0, 60.0, 30.0];
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 24),
          Row(
            children: [
              _overviewItem('12', '天'),
              const SizedBox(width: 48),
              _overviewItem('8.5', '小时'),
              const SizedBox(width: 48),
              _overviewItem('3', '本'),
            ],
          ),
          const SizedBox(height: 40),
          const Text('本周阅读',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
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
                        toY: weeklyData[entry.key],
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
          _categoryRow('科幻', 3, 0.3),
          _categoryRow('文学', 2, 0.5),
          _categoryRow('历史', 1, 0.7),
          _categoryRow('其他', 0, 0.9),
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

  Widget _categoryRow(String name, int count, double opacity) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.primary.withValues(alpha: opacity),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name,
            style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary),
          )),
          Text('$count 本',
            style: const TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
          ),
        ],
      ),
    );
  }
}
