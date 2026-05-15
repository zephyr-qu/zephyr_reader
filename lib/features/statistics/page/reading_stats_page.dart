library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class ReadingStatsPage extends HookWidget {
  const ReadingStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weeklyData = [
      _DayData('周一', 45, 12000),
      _DayData('周二', 60, 15000),
      _DayData('周三', 30, 8000),
      _DayData('周四', 90, 22000),
      _DayData('周五', 75, 18000),
      _DayData('周六', 120, 30000),
      _DayData('周日', 100, 25000),
    ];

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
              _statItem('阅读时长', '8.5 小时'),
              const SizedBox(width: 48),
              _statItem('阅读字数', '13 万字'),
              const SizedBox(width: 48),
              _statItem('阅读天数', '5 天'),
            ],
          ),
          const SizedBox(height: 32),
          const Text('本周阅读时长',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 150,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem('${rod.toY}分钟',
                        TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= weeklyData.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(weeklyData[value.toInt()].day,
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
                barGroups: weeklyData.asMap().entries.map((entry) =>
                  BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.minutes.toDouble(),
                        color: theme.colorScheme.primary,
                        width: 8,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(2), topRight: Radius.circular(2)),
                      ),
                    ],
                  ),
                ).toList(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('阅读习惯',
            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
          ),
          const Divider(height: 12),
          _habitRow('最佳阅读时间', '晚上 8-10 点'),
          _habitRow('平均阅读速度', '350 字/分钟'),
          _habitRow('连续阅读天数', '12 天'),
          _habitRow('偏好题材', '科幻'),
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

class _DayData {
  final String day;
  final int minutes;
  final int characters;
  _DayData(this.day, this.minutes, this.characters);
}
