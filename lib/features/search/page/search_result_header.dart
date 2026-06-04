import 'package:flutter/material.dart';

import 'search_results.dart';

// ──────────────────────── Summary Bar ────────────────────────

class SearchSummaryBar extends StatelessWidget {
  final SearchResults results;
  const SearchSummaryBar({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        '找到 ${results.totalCount} 条结果 · 耗时 ${results.durationMs}ms',
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
                  style: TextStyle(
                    fontSize: 13,
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

// ──────────────────────── Highlighted Snippet ────────────────────────

Widget buildHighlightedSnippet(ThemeData theme, String text, String query) {
  if (query.isEmpty) {
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.4,
      ),
    );
  }

  final lowerText = text.toLowerCase();
  final lowerQuery = query.toLowerCase();
  final spans = <InlineSpan>[];
  int lastEnd = 0;

  int startIndex = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, startIndex);
    if (idx == -1) break;
    if (idx > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, idx)));
    }
    spans.add(
      TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: Colors.yellow.withValues(alpha: 0.4),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    lastEnd = idx + query.length;
    startIndex = idx + 1;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return RichText(
    text: TextSpan(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.4,
      ),
      children: spans,
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );
}
