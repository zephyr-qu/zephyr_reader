import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

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
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          SliverAppBar(
            floating: true,
            title: const Text('阅读统计'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  // 刷新统计数据
                },
                tooltip: '刷新',
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isTabletOrDesktop)
                    ..._buildTabletLayout(context, theme)
                  else
                    ..._buildPhoneLayout(context, theme),
                  SizedBox(height: LayoutBreakpoints.getSpacing(context)),
                ],
              ),
            ),
          ),
        ],
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
      _buildSectionHeader(context, '阅读时长趋势'),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildReadingTimeChart(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 书籍分类统计
      _buildSectionHeader(context, '书籍分类'),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildCategoryStats(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 详细统计
      _buildSectionHeader(context, '详细统计'),
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
                _buildSectionHeader(context, '阅读时长趋势'),
                SizedBox(height: spacing / 2),
                _buildReadingTimeChart(context),
              ],
            ),
          ),
          SizedBox(width: spacing),
          // 右侧：书籍分类统计 + 详细统计
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryStats(context),
                SizedBox(height: spacing),
                _buildSectionHeader(context, '详细统计'),
                SizedBox(height: spacing / 2),
                _buildDetailedStats(context),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    return GradientCard(
      padding: EdgeInsets.all(LayoutBreakpoints.getCardPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '阅读概览',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isTabletOrDesktop ? 24 : 20),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: '累计阅读',
                  value: '156h',
                  icon: Icons.schedule,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: isTabletOrDesktop ? 16 : 12),
              Expanded(
                child: StatCard(
                  label: '已读书籍',
                  value: '24',
                  icon: Icons.book_online,
                  color: theme.colorScheme.secondary,
                ),
              ),
              SizedBox(width: isTabletOrDesktop ? 16 : 12),
              Expanded(
                child: StatCard(
                  label: '阅读天数',
                  value: '89',
                  icon: Icons.calendar_today,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '本周阅读',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '总计 42h',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
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
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
                          const titles = [
                            '周一',
                            '周二',
                            '周三',
                            '周四',
                            '周五',
                            '周六',
                            '周日',
                          ];
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              titles[value.toInt()],
                              style: theme.textTheme.bodySmall?.copyWith(
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
                    _buildBarGroup(0, 5, theme),
                    _buildBarGroup(1, 7, theme),
                    _buildBarGroup(2, 3, theme),
                    _buildBarGroup(3, 8, theme),
                    _buildBarGroup(4, 6, theme),
                    _buildBarGroup(5, 9, theme),
                    _buildBarGroup(6, 4, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, ThemeData theme) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryStats(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isTabletOrDesktop = deviceType != DeviceType.phone;
    final pieHeight = isTabletOrDesktop ? 200.0 : 160.0;
    final pieRadius = isTabletOrDesktop ? 80.0 : 65.0;
    final centerSpaceRadius = isTabletOrDesktop ? 55.0 : 45.0;

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
              child: Stack(
                children: [
                  PieChart(
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
                      sectionsSpace: 3,
                      centerSpaceRadius: centerSpaceRadius,
                    ),
                  ),
                  // 中心文字
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '24',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '本书',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTabletOrDesktop ? 24 : 20),
            Wrap(
              spacing: isTabletOrDesktop ? 20 : 16,
              runSpacing: isTabletOrDesktop ? 12 : 8,
              children: categories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: (category['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isTabletOrDesktop ? 12 : 10,
                        height: isTabletOrDesktop ? 12 : 10,
                        decoration: BoxDecoration(
                          color: category['color'] as Color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: isTabletOrDesktop ? 8 : 6),
                      Text(
                        '${category['name']} ${category['count']}',
                        style: isTabletOrDesktop
                            ? theme.textTheme.bodyMedium
                            : theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
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
      {
        'label': '平均每天阅读',
        'value': '1.5h',
        'icon': Icons.schedule,
        'color': theme.colorScheme.primary,
      },
      {
        'label': '最长连续阅读',
        'value': '12 天',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
      },
      {
        'label': '笔记总数',
        'value': '156 条',
        'icon': Icons.note_alt,
        'color': theme.colorScheme.tertiary,
      },
      {
        'label': '书签总数',
        'value': '89 个',
        'icon': Icons.bookmark,
        'color': theme.colorScheme.secondary,
      },
      {
        'label': '本周阅读',
        'value': '8.5h',
        'icon': Icons.today,
        'color': theme.colorScheme.primary,
      },
      {
        'label': '本月阅读',
        'value': '32h',
        'icon': Icons.calendar_month,
        'color': theme.colorScheme.tertiary,
      },
    ];

    return Card(
      child: Column(
        children: stats
            .asMap()
            .entries
            .map(
              (entry) => _buildStatListItem(
                context,
                entry.value['label'] as String,
                entry.value['value'] as String,
                entry.value['icon'] as IconData,
                entry.value['color'] as Color,
                isTabletOrDesktop,
                theme,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStatListItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    bool isTabletOrDesktop,
    ThemeData theme,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: isTabletOrDesktop ? 24 : 20),
      ),
      title: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: isTabletOrDesktop ? 16 : null,
          ),
        ),
      ),
    );
  }
}
