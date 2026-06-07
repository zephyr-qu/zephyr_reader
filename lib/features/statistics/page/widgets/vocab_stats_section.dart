import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/vocab_stat_bar.dart';

/// 生词统计区块。
///
/// 显示未开始、学习中、已掌握、已忽略的生词数量及进度条。
class VocabStatsSection extends StatelessWidget {
  final int vocabUnstarted;
  final int vocabLearning;
  final int vocabMastered;
  final int vocabIgnored;

  const VocabStatsSection({
    super.key,
    required this.vocabUnstarted,
    required this.vocabLearning,
    required this.vocabMastered,
    required this.vocabIgnored,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final total = vocabUnstarted + vocabLearning + vocabMastered + vocabIgnored;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.vocabStats,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                VocabStatBar(
                  label: l10n.statusUnlearned,
                  count: vocabUnstarted,
                  total: total,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                VocabStatBar(
                  label: l10n.statusLearning,
                  count: vocabLearning,
                  total: total,
                  color: cs.tertiary,
                ),
                const SizedBox(width: 8),
                VocabStatBar(
                  label: l10n.statusMastered,
                  count: vocabMastered,
                  total: total,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                VocabStatBar(
                  label: l10n.statusIgnored,
                  count: vocabIgnored,
                  total: total,
                  color: cs.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
