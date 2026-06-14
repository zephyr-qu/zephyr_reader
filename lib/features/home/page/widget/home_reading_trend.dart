import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读趋势图表。
///
/// 使用 fl_chart 绘制柱状图，展示近期的每日阅读时长。
class ReadingTrend extends StatelessWidget {
  const ReadingTrend({super.key, required this.dailyRecords});

  final List<ReadingStats> dailyRecords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final df = DateFormat('E', locale);
    final dateMap = <String, double>{};
    for (final r in dailyRecords) {
      dateMap[r.date] = r.readingTimeSeconds.toDouble() / 60.0;
    }
    final now = DateTime.now();
    final spots = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      return FlSpot(i.toDouble(), dateMap[key] ?? 0);
    });
    final maxVal = spots.fold<double>(0, (m, s) => m > s.y ? m : s.y);
    final ceiling = maxVal > 0 ? (maxVal * 1.3).ceilToDouble() : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.readingTrend,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: DesignTokens.spacing(Spacing.sm)),
        if (maxVal == 0)
          SizedBox(
            height: 180,
            child: Center(
              child: Text(
                l10n.noReadingRecord,
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      preventCurveOverShooting: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
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
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() == 0 || value.toInt() == 6) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              df.format(
                                now.subtract(Duration(days: 6 - value.toInt())),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: ceiling,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
