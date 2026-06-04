import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class WeeklyHeatmap extends StatelessWidget {
  final List<ReadingStats> records;

  const WeeklyHeatmap({super.key, required this.records});


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final weekday = i + 1; // DateTime.monday=1
                return SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      for (int w = 0; w < 4; w++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _heatmapColor(
                              cs,
                              _getWeekMinutes(w, weekday),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        _weekdayLabel(l10n, i),
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  int _getWeekMinutes(int weekOffset, int weekday) {
    var total = 0;
    for (final r in records) {
      try {
        final dt = DateTime.parse(r.date);
        if (dt.weekday == weekday) {
          total += r.readingTimeSeconds.toInt();
        }
      } catch (e) {
        Logging.error('解析阅读日期失败', exception: e);
      }
    }
    return total;
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
