import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Filter chips row for vocabulary status and word list selection.
///
/// Shows two horizontal scrollable rows:
/// 1. Status chips (全部/未学/学习中/已忽略/已掌握) with counts.
/// 2. Word-list chips passed via [wordLists].
class VocabStatsRow extends StatelessWidget {
  final AsyncState<VocabStats?> stats;
  final VocabStatus? filterStatus;
  final String? filterWordList;
  final List<String> wordLists;
  final ValueChanged<VocabStatus?> onFilterChanged;
  final ValueChanged<String?> onWordListFilterChanged;

  const VocabStatsRow({
    super.key,
    required this.stats,
    required this.filterStatus,
    required this.filterWordList,
    required this.wordLists,
    required this.onFilterChanged,
    required this.onWordListFilterChanged,
  });

  static int _countForStatus(VocabStatus status, VocabStats stats) =>
      switch (status) {
        VocabStatus.unstarted => stats.unstartedCount.toInt(),
        VocabStatus.learning => stats.learningCount.toInt(),
        VocabStatus.mastered => stats.masteredCount.toInt(),
        VocabStatus.ignored => stats.ignoredCount.toInt(),
      };

  static String _labelForStatus(
    VocabStatus status,
    AppLocalizations l10n,
    int count,
  ) => switch (status) {
    VocabStatus.unstarted => l10n.vocabStatsUnstarted(count.toString()),
    VocabStatus.learning => l10n.vocabStatsLearning(count.toString()),
    VocabStatus.mastered => l10n.vocabStatsMastered(count.toString()),
    VocabStatus.ignored => l10n.vocabStatsIgnored(count.toString()),
  };
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    const chipPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 6);
    return stats.map(
      data: (VocabStats? s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SelectionChip(
                    label: l10n!.vocabStatsAll(s!.totalWords.toString()),
                    selected: filterStatus == null,
                    onTap: () => onFilterChanged(null),
                    padding: chipPadding,
                    inactiveBgColor: cs.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 8),
                  for (final status in VocabStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectionChip(
                        label: _labelForStatus(
                          status,
                          l10n,
                          _countForStatus(status, s),
                        ),
                        selected: filterStatus == status,
                        onTap: () => onFilterChanged(status),
                        padding: chipPadding,
                        inactiveBgColor: cs.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SelectionChip(
                    label: l10n.allWordLists,
                    selected: filterWordList == null,
                    onTap: () => onWordListFilterChanged(null),
                    activeColor: cs.secondary,
                    padding: chipPadding,
                    inactiveBgColor: cs.surfaceContainerHighest,
                  ),
                  const SizedBox(width: 8),
                  for (final wl in wordLists)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectionChip(
                        label: wl,
                        selected: filterWordList == wl,
                        onTap: () => onWordListFilterChanged(wl),
                        activeColor: cs.secondary,
                        padding: chipPadding,
                        inactiveBgColor: cs.surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      error: () => const SizedBox.shrink(),
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
