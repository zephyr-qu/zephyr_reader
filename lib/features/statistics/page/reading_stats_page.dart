/// 阅读统计图表页面
///
/// 展示阅读时长、字数等统计数据的图
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 阅读统计页面
class ReadingStatsPage extends HookWidget {
  const ReadingStatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 模拟数据
    final weeklyData = useState([
      WeeklyStatData(day: '周一', minutes: 45, characters: 12000),
      WeeklyStatData(day: '周二', minutes: 60, characters: 15000),
      WeeklyStatData(day: '周三', minutes: 30, characters: 8000),
      WeeklyStatData(day: '周四', minutes: 90, characters: 22000),
      WeeklyStatData(day: '周五', minutes: 75, characters: 18000),
      WeeklyStatData(day: '周六', minutes: 120, characters: 30000),
      WeeklyStatData(day: '周日', minutes: 100, characters: 25000),
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text('阅读统计')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总览卡片
            _buildOverviewCard(context),
            const SizedBox(height: 24),
            // 周统计图
            _buildWeeklyChartCard(context, weeklyData.value),
            const SizedBox(height: 24),
            // 阅读习惯
            _buildHabitCard(context),
            const SizedBox(height: 24),
            // 成就卡片
            _buildAchievementCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本周总览',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(context, '阅读时长', '8.5 小时', Icons.timer_outlined),
                _buildStatItem(context, '阅读字数', '13 万字', Icons.text_fields),
                _buildStatItem(context, '阅读天数', '5 ', Icons.calendar_today),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildWeeklyChartCard(
    BuildContext context,
    List<WeeklyStatData> data,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '本周阅读时长',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 150,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY}分钟',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= data.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()].day,
                              style: const TextStyle(fontSize: 12),
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
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data
                      .asMap()
                      .entries
                      .map(
                        (entry) => BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: entry.value.minutes.toDouble(),
                              color: Colors.teal,
                              width: 20,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(6),
                                topRight: Radius.circular(6),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读习惯',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildHabitItem(theme, '最佳阅读时', '晚上 8-10 ', '这段时间阅读效率最'),
            const Divider(),
            _buildHabitItem(theme, '平均阅读速度', '350 分钟', '高于平均水平'),
            const Divider(),
            _buildHabitItem(theme, '连续阅读天数', '12 ', '继续保持'),
            const Divider(),
            _buildHabitItem(theme, '偏好题材', '科幻/技', '最近阅读较'),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitItem(
    ThemeData theme,
    String title,
    String value,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读成就',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildAchievementChip('📚 书海新人', '阅读 1 本书', true),
                _buildAchievementChip('🔥 坚持不懈', '连续阅读 7 ', true),
                _buildAchievementChip('阅读达人', '阅读 10 本书', false),
                _buildAchievementChip('🏆 博学多才', '阅读 50 本书', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementChip(
    String title,
    String description,
    bool unlocked,
  ) {
    return Chip(
      avatar: Text(unlocked ? '' : '🔒'),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: unlocked ? null : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: unlocked ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// 周统计数
class WeeklyStatData {
  final String day;
  final int minutes;
  final int characters;

  WeeklyStatData({
    required this.day,
    required this.minutes,
    required this.characters,
  });
}
