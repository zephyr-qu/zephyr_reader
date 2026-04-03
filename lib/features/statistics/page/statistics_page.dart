import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

/// 统计页面 - 展示阅读数据统计
class StatisticsPage extends HookWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);
    final isTabletOrDesktop = deviceType != DeviceType.phone;
    final statsService = ReadingStatsService.instance;

    // 加载统计数据
    final statsAsync = useFuture(
      useMemoized(() => statsService.getStatistics(), []),
    );
    final dailyRecordsAsync = useFuture(
      useMemoized(() => statsService.getDailyRecords(days: 7), []),
    );

    final stats = statsAsync.data;
    final dailyRecords = dailyRecordsAsync.data ?? [];

    // 准备图表数据
    final chartData = _prepareChartData(dailyRecords);

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
                  statsService.getStatistics();
                  statsService.getDailyRecords(days: 7);
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
                    ..._buildTabletLayout(context, theme, stats, chartData)
                  else
                    ..._buildPhoneLayout(context, theme, stats, chartData),
                  SizedBox(height: LayoutBreakpoints.getSpacing(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 准备图表数据
  List<ChartData> _prepareChartData(List<DailyReadingRecord> records) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final data = <ChartData>[];

    // 生成最近7天的数据
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final weekdayIndex = (date.weekday - 1) % 7;

      // 查找对应日期的记录
      final record = records.firstWhere(
        (r) =>
            r.date.year == date.year &&
            r.date.month == date.month &&
            r.date.day == date.day,
        orElse: () => DailyReadingRecord(
          date: date,
          readingTimeSeconds: 0,
          charactersRead: 0,
          chaptersRead: 0,
          pagesRead: 0,
        ),
      );

      data.add(
        ChartData(
          day: weekdays[weekdayIndex],
          hours: record.readingTimeSeconds / 3600,
          characters: record.charactersRead,
        ),
      );
    }

    return data;
  }

  /// 手机布局
  List<Widget> _buildPhoneLayout(
    BuildContext context,
    ThemeData theme,
    ReadingStatistics? stats,
    List<ChartData> chartData,
  ) {
    return [
      // 总览卡片
      _buildOverviewCard(context, stats),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 阅读时长趋势
      _buildSectionHeader(context, '阅读时长趋势'),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildReadingTimeChart(context, chartData),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 书籍分类统计
      _buildSectionHeader(context, '书籍分类'),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildCategoryStats(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      // 详细统计
      _buildSectionHeader(context, '详细统计'),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildDetailedStats(context, stats),
    ];
  }

  /// 平板/桌面布局
  List<Widget> _buildTabletLayout(
    BuildContext context,
    ThemeData theme,
    ReadingStatistics? stats,
    List<ChartData> chartData,
  ) {
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
                _buildOverviewCard(context, stats),
                SizedBox(height: spacing),
                _buildSectionHeader(context, '阅读时长趋势'),
                SizedBox(height: spacing / 2),
                _buildReadingTimeChart(context, chartData),
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
                _buildDetailedStats(context, stats),
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

  Widget _buildOverviewCard(BuildContext context, ReadingStatistics? stats) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    // 格式化数据
    final totalHours = stats != null
        ? (stats.totalReadingTimeSeconds / 3600).toStringAsFixed(1)
        : '0';
    final totalBooks = stats?.booksReadCount ?? 0;
    final readingDays = stats?.consecutiveReadingDays ?? 0;

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
                  value: '${totalHours}h',
                  icon: Icons.schedule,
                  color: theme.colorScheme.primary,
                ),
              ),
              SizedBox(width: isTabletOrDesktop ? 16 : 12),
              Expanded(
                child: StatCard(
                  label: '已读书籍',
                  value: '$totalBooks',
                  icon: Icons.book_online,
                  color: theme.colorScheme.secondary,
                ),
              ),
              SizedBox(width: isTabletOrDesktop ? 16 : 12),
              Expanded(
                child: StatCard(
                  label: '阅读天数',
                  value: '$readingDays',
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

  Widget _buildReadingTimeChart(BuildContext context, List<ChartData> data) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;
    final chartHeight = isTabletOrDesktop ? 250.0 : 200.0;

    // 计算总阅读时长
    final totalHours = data.fold<double>(0, (sum, item) => sum + item.hours);

    // 计算最大值用于图表缩放
    final maxHours = data.isNotEmpty
        ? data.map((d) => d.hours).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final yMax = maxHours > 0 ? (maxHours * 1.2).ceil().toDouble() : 10.0;

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
                    '总计 ${totalHours.toStringAsFixed(1)}h',
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
              child: data.isEmpty || totalHours == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.show_chart,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无阅读数据',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: yMax,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toStringAsFixed(1)}h',
                                const TextStyle(
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
                                if (value.toInt() >= data.length) {
                                  return const Text('');
                                }
                                return SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    data[value.toInt()].day,
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
                          horizontalInterval: maxHours > 0 ? maxHours / 5 : 2,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.1,
                              ),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: data
                            .asMap()
                            .entries
                            .map(
                              (entry) => BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.hours,
                                    gradient: LinearGradient(
                                      colors: [
                                        theme.colorScheme.primary,
                                        theme.colorScheme.primary.withValues(
                                          alpha: 0.6,
                                        ),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
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

  Widget _buildDetailedStats(BuildContext context, ReadingStatistics? stats) {
    final theme = Theme.of(context);
    final isTabletOrDesktop =
        LayoutBreakpoints.getDeviceType(context) != DeviceType.phone;

    // 计算统计数据
    final avgDailyHours = stats != null && stats.consecutiveReadingDays > 0
        ? (stats.totalReadingTimeSeconds / 3600) / stats.consecutiveReadingDays
        : 0.0;
    final readingSpeed = stats?.averageReadingSpeed ?? 0;
    final completedBooks = stats?.booksCompletedCount ?? 0;
    final totalChars = ((stats?.totalCharactersRead ?? 0) / 10000)
        .toStringAsFixed(1);

    final statsList = [
      {
        'label': '平均每天阅读',
        'value': '${avgDailyHours.toStringAsFixed(1)}h',
        'icon': Icons.schedule,
        'color': theme.colorScheme.primary,
      },
      {
        'label': '连续阅读天数',
        'value': '${stats?.consecutiveReadingDays ?? 0} 天',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
      },
      {
        'label': '阅读速度',
        'value': '${readingSpeed.toStringAsFixed(0)} 字/分钟',
        'icon': Icons.speed,
        'color': theme.colorScheme.tertiary,
      },
      {
        'label': '已完成书籍',
        'value': '$completedBooks 本',
        'icon': Icons.check_circle,
        'color': theme.colorScheme.secondary,
      },
      {
        'label': '本周阅读',
        'value':
            '${((stats?.todayReadingTimeSeconds ?? 0) / 3600).toStringAsFixed(1)}h',
        'icon': Icons.today,
        'color': theme.colorScheme.primary,
      },
      {
        'label': '累计阅读字数',
        'value': '$totalChars 万字',
        'icon': Icons.text_fields,
        'color': theme.colorScheme.tertiary,
      },
    ];

    return Card(
      child: Column(
        children: statsList
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

/// 图表数据类
class ChartData {
  final String day;
  final double hours;
  final int characters;

  ChartData({required this.day, required this.hours, required this.characters});
}
