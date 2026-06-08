import 'package:flutter/material.dart';

import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Semantic color for a VocabStatus, fully theme-aware.
Color vocabStatusColor(VocabStatus status, ThemeData theme) => switch (status) {
  VocabStatus.unstarted ||
  VocabStatus.ignored => theme.colorScheme.onSurfaceVariant,
  VocabStatus.learning => theme.colorScheme.tertiary,
  VocabStatus.mastered => theme.colorScheme.primary,
};
String vocabStatusLabel(VocabStatus status, AppLocalizations l10n) =>
    switch (status) {
      VocabStatus.unstarted => l10n.statusUnlearned,
      VocabStatus.learning => l10n.statusLearning,
      VocabStatus.mastered => l10n.statusMastered,
      VocabStatus.ignored => l10n.statusIgnored,
    };

/// A small colored pill showing the vocabulary status label.
///
/// Renders a rounded chip with a tinted background and the status name,
/// using [vocabStatusColor] for dark-mode–safe coloring.
class VocabStatusChip extends StatelessWidget {
  final VocabStatus status;

  const VocabStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
        vocabStatusLabel(status, l10n),
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }
}
