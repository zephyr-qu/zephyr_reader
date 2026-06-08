import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/utils/time_formatters.dart';

/// 阅读会话总览卡片。
///
/// 渐变背景，左侧显示总阅读时长，右侧显示总会话次数。
class ReadingSessionOverviewCard extends StatelessWidget {
  final int totalSessions;
  final int totalDuration;

  const ReadingSessionOverviewCard({
    super.key,
    required this.totalSessions,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDuration(totalDuration, l10n),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  l10n.totalReadingTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$totalSessions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                l10n.sessionsCount,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onPrimaryContainer.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
