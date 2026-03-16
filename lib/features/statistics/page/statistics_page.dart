import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';

/// 统计页面 - 展示阅读数据统计
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);
    final isTabletOrDesktop = deviceType != DeviceType.phone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 刷新统计数据
              // TODO: 调用 ReadingStatsService 刷新数据
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('统计数据已刷�?')));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 刷新数据
          // TODO: 实现实际的数据刷新逻辑
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTabletOrDesktop)
                ..._buildTabletLayout(context, theme)
              else
                ..._buildPhoneLayout(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 手机布局
  List<Widget> _buildPhoneLayout(BuildContext context, ThemeData theme) {
    return [
      // 总览卡片
      _buildOverviewCard(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 阅读时长趋势
      Text('阅读时长趋势', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildReadingTimeChart(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 书籍分类统计
      Text('书籍分类', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildCategoryStats(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 详细统计
      Text('详细统计', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildDetailedStats(context),
    ];
  }

  /// 平板/桌面布局
  List<Widget> _buildTabletLayout(BuildContext context, ThemeData theme) {
    final spacing = LayoutBreakpoints.getSpacing(context);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：总览卡片 + 阅读时长趋势
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(context),
                SizedBox(height: spacing),
                Text('阅读时长趋势', style: theme.textTheme.titleLarge),
                SizedBox(height: spacing / 2),
                _buildReadingTimeChart(context),
              ],
            ),
          ),
          SizedBox(width: spacing),
          // 右侧：书籍分类统�?+ 详细统计
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryStats(context),
                SizedBox(height: spacing),
                Text('详细统计', style: theme.textTheme.titleLarge),
                SizedBox(height: spacing / 2),
                _buildDetailedStats(context),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(LayoutBreakpoints.getCardPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('阅读概览', style: theme.textTheme.titleMedium),
            SizedBox(height: isTabletOrDesktop ? 24 : 20),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    '累计阅读',
                    '156 小时',
                    theme.colorScheme.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    '已读书籍',
                    '24 �?',
                    theme.colorScheme.secondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildOverviewItem(
                    context,
                    '阅读天数',
                    '89 �?',
                    theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: isTabletOrDesktop ? 24 : null,
          ),
        ),
        SizedBox(height: isTabletOrDesktop ? 6 : 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: isTabletOrDesktop ? 14 : null,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingTimeChart(BuildContext context) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;
    final chartHeight = isTabletOrDesktop ? 250.0 : 200.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(LayoutBreakpoints.getCardPadding(context)),
        child: SizedBox(
          height: chartHeight,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 10,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY}h',
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
                      const titles = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          titles[value.toInt()],
                          style: theme.textTheme.bodySmall,
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
                horizontalInterval: 2,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [
                    BarChartRodData(
                      toY: 5,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [
                    BarChartRodData(
                      toY: 7,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [
                    BarChartRodData(
                      toY: 3,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 3,
                  barRods: [
                    BarChartRodData(
                      toY: 8,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 4,
                  barRods: [
                    BarChartRodData(
                      toY: 6,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 5,
                  barRods: [
                    BarChartRodData(
                      toY: 9,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
                BarChartGroupData(
                  x: 6,
                  barRods: [
                    BarChartRodData(
                      toY: 4,
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryStats(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isTabletOrDesktop = deviceType != DeviceType.phone;
    final pieHeight = isTabletOrDesktop ? 180.0 : 150.0;
    final pieRadius = isTabletOrDesktop ? 70.0 : 60.0;
    final centerSpaceRadius = isTabletOrDesktop ? 50.0 : 40.0;

    final categories = [
      {'name': '科幻', 'count': 8, 'color': theme.colorScheme.primary},
      {'name': '文学', 'count': 6, 'color': theme.colorScheme.secondary},
      {'name': '历史', 'count': 5, 'color': theme.colorScheme.tertiary},
      {'name': '其他', 'count': 5, 'color': theme.colorScheme.error},
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(LayoutBreakpoints.getCardPadding(context)),
        child: Column(
          children: [
            SizedBox(
              height: pieHeight,
              child: PieChart(
                PieChartData(
                  sections: categories.asMap().entries.map((entry) {
                    final category = entry.value;
                    return PieChartSectionData(
                      value: (category['count'] as int).toDouble(),
                      title: '',
                      color: category['color'] as Color,
                      radius: pieRadius,
                      titleStyle: const TextStyle(fontSize: 0),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: centerSpaceRadius,
                ),
              ),
            ),
            SizedBox(height: isTabletOrDesktop ? 24 : 20),
            Wrap(
              spacing: isTabletOrDesktop ? 20 : 16,
              runSpacing: isTabletOrDesktop ? 12 : 8,
              children: categories.map((category) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isTabletOrDesktop ? 14 : 12,
                      height: isTabletOrDesktop ? 14 : 12,
                      decoration: BoxDecoration(
                        color: category['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: isTabletOrDesktop ? 8 : 6),
                    Text(
                      '${category['name']} ${category['count']}�?',
                      style: isTabletOrDesktop
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall,
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStats(BuildContext context) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    final stats = [
      {'label': '平均每天阅读', 'value': '1.5 小时', 'icon': Icons.schedule},
      {'label': '最长连续阅读', 'value': '12 天', 'icon': Icons.local_fire_department},
      {'label': '笔记总数', 'value': '156 条', 'icon': Icons.note},
      {'label': '书签总数', 'value': '89 个', 'icon': Icons.bookmark},
      {'label': '本周阅读', 'value': '8.5 小时', 'icon': Icons.today},
      {'label': '本月阅读', 'value': '32 小时', 'icon': Icons.calendar_month},
    ];

    return Card(
      child: Column(
        children: stats
            .map(
              (stat) => ListTile(
                leading: Icon(
                  stat['icon'] as IconData,
                  color: theme.colorScheme.primary,
                ),
                title: Text(stat['label'] as String),
                trailing: Text(
                  stat['value'] as String,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTabletOrDesktop ? 16 : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
