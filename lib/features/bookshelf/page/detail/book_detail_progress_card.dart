import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读进度统计卡片
class BookDetailProgressCard extends StatelessWidget {
  final ReadingProgress progress;
  final int sessionCount;
  const BookDetailProgressCard({
    super.key,
    required this.progress,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pct = (progress.progress) * 100;
    final totalMinutes = (progress.readingTimeSeconds.toInt()) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    // Estimated remaining time
    String? remainingStr;
    final p = progress.progress;
    final readingTime = progress.readingTimeSeconds.toDouble();
    if (p > 0.01 && readingTime > 0) {
      final remainingSec = ((1.0 - p) * readingTime / p).round();
      if (remainingSec > 0) {
        final rh = remainingSec ~/ 3600;
        final rm = (remainingSec % 3600) ~/ 60;
        remainingStr = rh > 0 ? '约 ${rh}h ${rm}min' : '约 ${rm}min';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.readingProgress,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 10),
          // Three stats
          Row(
            children: [
              _statItem(theme, timeStr, l10n.statReadingTime),
              _statItem(theme, '$sessionCount', l10n.statReadingCount),
              if (remainingStr != null)
                _statItem(theme, remainingStr, l10n.statEstimatedRemaining),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
