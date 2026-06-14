import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import '../search_results.dart';

// ──────────────────────── Summary Bar ────────────────────────

/// 搜索结果摘要栏。
///
/// 显示搜索结果的来源分布统计（书籍/笔记/生词）。
class SearchSummaryBar extends StatelessWidget {
  final SearchResults results;
  const SearchSummaryBar({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        l10n.resultSummary('${results.totalCount}', '${results.durationMs}'),
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}

// ──────────────────────── Result Group Header ────────────────────────

class ResultGroupHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final List<Widget> children;

  const ResultGroupHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
