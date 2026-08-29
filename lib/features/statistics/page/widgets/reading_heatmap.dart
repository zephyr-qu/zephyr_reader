import 'package:zephyr_reader/src/rust/domain/stats/models.dart';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 30 天阅读热力图组件。
///
/// 以 3×10 网格展示过去 30 天的阅读情况，色块深浅反映当日阅读时长。
/// 今天固定在网格最后一格（index 29 = row 2 col 9），每天自动滚动。
class ReadingHeatmap extends StatelessWidget {
  final List<DailyReadingStats> records;

  const ReadingHeatmap({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final gridStart = todayDate.subtract(const Duration(days: 29));
    const totalDays = 30;
    const rows = 3;
    const cols = 10;

    final grid = _buildGrid(gridStart, totalDays, rows, cols);

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        const hPadding = 32.0; // EdgeInsets.all(16) × 2
        const maxCell = 32.0;
        final cellSize =
            ((constraints.maxWidth - hPadding - (cols - 1) * gap) / cols)
                .clamp(0, maxCell)
                .toDouble();

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
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int c = 0; c < cols; c++) ...[
                            if (c > 0) const SizedBox(width: gap),
                            _buildCell(
                              context,
                              seconds: grid[r][c],
                              dayOffset: r * cols + c,
                              gridStart: gridStart,
                              todayDate: todayDate,
                              size: cellSize,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(
    BuildContext context, {
    required int seconds,
    required int dayOffset,
    required DateTime gridStart,
    required DateTime todayDate,
    required double size,
  }) {
    final cs = Theme.of(context).colorScheme;
    final cellDate = gridStart.add(Duration(days: dayOffset));
    final dayNumber = cellDate.day;
    final isFuture = cellDate.isAfter(todayDate);

    final Color bgColor = isFuture
        ? cs.surfaceContainerHighest.withValues(alpha: 0.3)
        : _heatmapColor(cs, seconds);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '$dayNumber',
        style: TextStyle(
          fontSize: 10,
          color: isFuture ? cs.onSurface.withValues(alpha: 0.25) : cs.onSurface,
        ),
      ),
    );
  }

  /// 按 30 天固定窗口构建热力图网格。
  /// 返回 `grid[row][col]`。
  List<List<int>> _buildGrid(
    DateTime gridStart,
    int totalDays,
    int rows,
    int cols,
  ) {
    final grid = List.generate(rows, (_) => List.filled(cols, 0));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    for (final r in records) {
      try {
        final dt = DateTime.parse(r.date);
        // 只显示今天及之前的数据
        if (dt.isAfter(todayDate)) continue;
        final diff = dt.difference(gridStart).inDays;
        if (diff < 0 || diff >= totalDays) continue;
        grid[diff ~/ cols][diff % cols] += r.readingTimeSeconds.toInt();
      } catch (e) {
        Logging.error('解析阅读日期失败', exception: e);
      }
    }
    return grid;
  }

  Color _heatmapColor(ColorScheme cs, int seconds) {
    if (seconds == 0) return cs.surfaceContainerHighest.withValues(alpha: 0.75);
    if (seconds < 600) return cs.primary.withValues(alpha: 0.15);
    if (seconds < 1800) return cs.primary.withValues(alpha: 0.35);
    return cs.primary.withValues(alpha: 0.6);
  }
}
