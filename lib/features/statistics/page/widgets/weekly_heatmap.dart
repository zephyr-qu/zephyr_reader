import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 月度阅读热力图组件。
///
/// 以网格形式展示一个自然月中每天的阅读情况，色块深浅反映当日阅读时长。
/// 从每月 1 号所在周的周一开始，到月末所在周的周日结束。
class WeeklyHeatmap extends StatelessWidget {
  final List<ReadingStats> records;

  const WeeklyHeatmap({super.key, required this.records});


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    // 自然月网格：从 1 号所在周的周一开始，到月末所在周的周日结束
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final gridEnd = monthEnd.add(Duration(days: DateTime.sunday - monthEnd.weekday));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final rows = totalDays ~/ 7; // 4-6 行

    final grid = _buildGrid(gridStart, totalDays, rows);

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
            ...List.generate(
              rows,
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (int d = 0; d < 7; d++) ...[
                      if (d > 0) const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _heatmapColor(cs, grid[w][d]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 按自然月起止构建热力图网格。
  /// 返回 `grid[row][weekday]`（weekday 0-indexed, Mon=0）。
  /// - 网格从 [gridStart] 到 gridStart 后 [totalDays]-1 天
  /// - 跨月日期（月末后几天）自然显示为 0（灰色）
  List<List<int>> _buildGrid(DateTime gridStart, int totalDays, int rows) {
    final grid = List.generate(rows, (_) => List.filled(7, 0));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (final r in records) {
      try {
        final dt = DateTime.parse(r.date);
        // 只显示今天及之前的数据
        if (dt.isAfter(todayDate)) continue;
        final diff = dt.difference(gridStart).inDays;
        if (diff < 0 || diff >= totalDays) continue;
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
}
