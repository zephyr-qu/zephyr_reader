import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class WeeklyHeatmap extends StatelessWidget {
  final List<ReadingStats> records;
  final StatisticsPeriod period;

  const WeeklyHeatmap({super.key, required this.records, required this.period});

  int get _days => switch (period) {
    StatisticsPeriod.today => 1,
    StatisticsPeriod.week => 7,
    StatisticsPeriod.month => 30,
    StatisticsPeriod.year => 365,
  };

  int get _weeks => (_days + 6) ~/ 7;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final grid = _buildGrid();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.readingHeatmap,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // 表头：空白 + 7 天
            Row(
              children: [
                const SizedBox(width: 32),
                ...List.generate(
                  7,
                  (i) => SizedBox(
                    width: 32,
                    child: Text(
                      _weekdayLabel(l10n, i),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 每行：周标签 + 7 格
            ...List.generate(
              _weeks,
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        _weekLabel(w),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...List.generate(
                      7,
                      (d) => Container(
                        margin: const EdgeInsets.only(left: 0),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _heatmapColor(cs, grid[w][d]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 周标签：显示该周起始日期（如 "6/1"）。
  String _weekLabel(int weekOffset) {
    final daysAgo = weekOffset * 7 + 6;
    final start = DateTime.now().subtract(Duration(days: daysAgo));
    return '${start.month}/${start.day}';
  }

  /// 按时段构建热力图数据网格，一次遍历。
  /// 返回 `grid[weekOffset][weekday]`（weekday 0-indexed, Mon=0）。
  List<List<int>> _buildGrid() {
    final grid = List.generate(_weeks, (_) => List.filled(7, 0));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (final r in records) {
      try {
        final dt = DateTime.parse(r.date);
        final diff = todayDate.difference(dt).inDays;
        if (diff < 0 || diff >= _days) continue;
        grid[diff ~/ 7][dt.weekday - 1] += r.readingTimeSeconds.toInt();
      } catch (e) {
        Logging.error('解析阅读日期失败', exception: e);
      }
    }
    return grid;
  }

  Color _heatmapColor(ColorScheme cs, int seconds) {
    if (seconds == 0) return cs.surfaceContainerHighest.withValues(alpha: 0.4);
    if (seconds < 600) return cs.primary.withValues(alpha: 0.15);
    if (seconds < 1800) return cs.primary.withValues(alpha: 0.35);
    if (seconds < 3600) return cs.primary.withValues(alpha: 0.55);
    return cs.primary.withValues(alpha: 0.75);
  }

  String _weekdayLabel(AppLocalizations l10n, int i) => switch (i) {
    0 => l10n.weekdayMon,
    1 => l10n.weekdayTue,
    2 => l10n.weekdayWed,
    3 => l10n.weekdayThu,
    4 => l10n.weekdayFri,
    5 => l10n.weekdaySat,
    6 => l10n.weekdaySun,
    _ => '',
  };
}
