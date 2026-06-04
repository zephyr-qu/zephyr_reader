import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/storage/vocab_status_extension.dart';

/// Semantic color for a VocabStatus, theme-aware for neutral statuses.
Color vocabStatusColor(VocabStatus status, ThemeData theme) => switch (status) {
  VocabStatus.unstarted || VocabStatus.ignored => theme.colorScheme.onSurfaceVariant,
  _ => status.color,
};

/// Name label for a VocabStatus.
String vocabStatusLabel(VocabStatus status) => status.displayName;

/// A small colored pill showing the vocabulary status label.
///
/// Renders a rounded chip with a tinted background and the status name,
/// using [vocabStatusColor] for dark-mode–safe coloring.
class VocabStatusChip extends StatelessWidget {
  final VocabStatus status;
  final ThemeData theme;

  const VocabStatusChip({
    super.key,
    required this.status,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = vocabStatusColor(status, theme);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing(Spacing.sm),
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        vocabStatusLabel(status),
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}
