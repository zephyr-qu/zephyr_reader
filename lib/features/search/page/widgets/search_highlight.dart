import 'package:flutter/material.dart';

/// 构建带关键词高亮的富文本片段。
///
/// 在 [text] 中匹配 [query]（不区分大小写），匹配部分用主题色高亮。
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
          backgroundColor: theme.colorScheme.primaryContainer,
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

  return Text.rich(
    TextSpan(
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.4,
      ),
      children: spans,
    ),
  );
}
