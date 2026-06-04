import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_view_model.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/today_reading_card.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/streak_card.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/reading_trend_chart.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/weekly_heatmap.dart';
import 'package:zephyr_reader/features/statistics/page/widgets/vocab_stats_section.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class StatisticsPage extends HookWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => ReadingStatsViewModel());
    useEffect(() {
      return null;
    }, []);

    final GlobalStats? gs = useSignalValue(vm.globalStats);
    final List<ReadingStats> records = useSignalValue(vm.dailyRecords);
    final StatisticsPeriod period = useSignalValue(vm.selectedPeriod);
    final int vUnstarted = useSignalValue(vm.vocabUnstarted);
    final int vLearning = useSignalValue(vm.vocabLearning);
    final int vMastered = useSignalValue(vm.vocabMastered);
    final int vIgnored = useSignalValue(vm.vocabIgnored);
    final bool loaded = useSignalValue(vm.loaded);
    final int goalMin = useSignalValue(vm.goalMinutes);

    final todayMin = gs != null ? gs.todayReadingTimeSeconds.toInt() ~/ 60 : 0;
    final pct = (todayMin / goalMin).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.statistics,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _PeriodSelector(
              selected: period,
              onChanged: (p) => vm.loadData(period: p),
            ),
          ),
        ],
      ),
      body: loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TodayReadingCard(
                        minutes: todayMin,
                        progress: pct,
                        goalMinutes: goalMin,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StreakCard(
                        days: gs?.consecutiveReadingDays ?? 0,
                        totalBooks: gs?.booksReadCount ?? 0,
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0),
                const SizedBox(height: 28),
                ReadingTrendChart(records: records)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms),
                const SizedBox(height: 28),
                WeeklyHeatmap(records: records)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms),
                const SizedBox(height: 28),
                VocabStatsSection(
                  vocabUnstarted: vUnstarted,
                  vocabLearning: vLearning,
                  vocabMastered: vMastered,
                  vocabIgnored: vIgnored,
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// ── Period Selector ──

class _PeriodSelector extends StatelessWidget {
  final StatisticsPeriod selected;
  final ValueChanged<StatisticsPeriod> onChanged;

  const _PeriodSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: StatisticsPeriod.values.map((period) {
          final isActive = period == selected;
          final labels = [
            l10n.periodToday,
            l10n.periodWeek,
            l10n.periodMonth,
            l10n.periodYear,
          ];
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onChanged(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? cs.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[period.index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
