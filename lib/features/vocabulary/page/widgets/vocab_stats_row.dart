import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Filter chips row for vocabulary status and word list selection.
///
/// Shows two horizontal scrollable rows:
/// 1. Status chips (全部/未学/学习中/已忽略/已掌握) with counts.
/// 2. Word-list chips passed via [wordLists].
class VocabStatsRow extends StatelessWidget {
  final ThemeData theme;
  final VocabStats? stats;
  final VocabStatus? filterStatus;
  final String? filterWordList;
  final List<String> wordLists;
  final ValueChanged<VocabStatus?> onFilterChanged;
  final ValueChanged<String?> onWordListFilterChanged;

  const VocabStatsRow({
    super.key,
    required this.theme,
    required this.stats,
    required this.filterStatus,
    required this.filterWordList,
    required this.wordLists,
    required this.onFilterChanged,
    required this.onWordListFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (stats == null) {
      return SizedBox(height: DesignTokens.spacing(Spacing.sm));
    }

    final cs = theme.colorScheme;
    final notStartedCount = stats!.unstartedCount.toInt();
    const chipPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SelectionChip(
                  label: '全部 ${stats!.totalWords}',
                  selected: filterStatus == null,
                  colorScheme: cs,
                  onTap: () => onFilterChanged(null),
                  padding: chipPadding,
                  inactiveBgColor: cs.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
                SelectionChip(
                  label: '未学 $notStartedCount',
                  selected: filterStatus == VocabStatus.unstarted,
                  colorScheme: cs,
                  onTap: () => onFilterChanged(VocabStatus.unstarted),
                  padding: chipPadding,
                  inactiveBgColor: cs.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
                SelectionChip(
                  label: '学习中 ${stats!.learningCount}',
                  selected: filterStatus == VocabStatus.learning,
                  colorScheme: cs,
                  onTap: () => onFilterChanged(VocabStatus.learning),
                  padding: chipPadding,
                  inactiveBgColor: cs.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
                SelectionChip(
                  label: '已忽略 ${stats!.ignoredCount}',
                  selected: filterStatus == VocabStatus.ignored,
                  colorScheme: cs,
                  onTap: () => onFilterChanged(VocabStatus.ignored),
                  padding: chipPadding,
                  inactiveBgColor: cs.surfaceContainerHighest,
                ),
                const SizedBox(width: 8),
                SelectionChip(
                  label: '已掌握 ${stats!.masteredCount}',
                  selected: filterStatus == VocabStatus.mastered,
                  colorScheme: cs,
                  onTap: () => onFilterChanged(VocabStatus.mastered),
                  padding: chipPadding,
                  inactiveBgColor: cs.surfaceContainerHighest,
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
                  label: '全部词库',
                  selected: filterWordList == null,
                  colorScheme: cs,
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
                      colorScheme: cs,
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
    );
  }
}
