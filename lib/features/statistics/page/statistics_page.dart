import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/statistics/application/statistics_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class StatisticsPage extends HookWidget {
  late final StatisticsViewModel vm = getIt<StatisticsViewModel>();
  StatisticsPage({super.key});

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final GlobalStats? gs = useSignalValue(vm.globalStats);
    final List<ReadingStats> records = useSignalValue(vm.dailyRecords);
    final StatisticsPeriod period = useSignalValue(vm.selectedPeriod);
    final int vNew = useSignalValue(vm.vocabNew);
    final int vLearning = useSignalValue(vm.vocabLearning);
    final int vMastered = useSignalValue(vm.vocabMastered);
    final int vIgnored = useSignalValue(vm.vocabIgnored);
    final bool loaded = useSignalValue(vm.loaded);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '阅读统计',
          style: TextStyle(
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
          ? _buildContent(
              cs,
              tt,
              gs,
              records,
              vNew,
              vLearning,
              vMastered,
              vIgnored,
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildContent(
    ColorScheme cs,
    TextTheme tt,
    GlobalStats? gs,
    List<ReadingStats> records,
    int vocabNew,
    int vocabLearning,
    int vocabMastered,
    int vocabIgnored,
  ) {
    final vocabTotal = vocabNew + vocabLearning + vocabMastered + vocabIgnored;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _buildDashboardSection(cs, tt, gs),
        const SizedBox(height: 28),
        _buildReadingTrendChart(cs, tt, records),
        const SizedBox(height: 28),
        _buildWeeklyHeatmap(cs, records),
        const SizedBox(height: 28),
        _buildVocabStats(
          cs,
          tt,
          vocabNew,
          vocabLearning,
          vocabMastered,
          vocabIgnored,
          vocabTotal,
        ),
      ],
    );
  }

  // ── Dashboard: 今日阅读 + 连续阅读 ──

  Widget _buildDashboardSection(ColorScheme cs, TextTheme tt, GlobalStats? gs) {
    final todayMin = gs != null ? gs.todayReadingTimeSeconds.toInt() ~/ 60 : 0;
    const goalMin = 60;
    final pct = (todayMin / goalMin).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: _todayCard(cs: cs, tt: tt, minutes: todayMin, progress: pct),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _streakCard(
            cs: cs,
            tt: tt,
            days: gs?.consecutiveReadingDays ?? 0,
            totalBooks: gs?.booksReadCount ?? 0,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _todayCard({
    required ColorScheme cs,
    required TextTheme tt,
    required int minutes,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.bookOpen, size: 14, color: cs.primary),
              const SizedBox(width: 4),
              Text(
                '今日阅读',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$minutes',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      letterSpacing: -1,
                      height: 1,
                    ),
                  ),
                  Text('分钟', style: tt.labelLarge),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3.5,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: cs.primary,
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: tt.labelSmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('目标 60 分钟', style: tt.labelSmall),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _streakCard({
    required ColorScheme cs,
    required TextTheme tt,
    required int days,
    required int totalBooks,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsRegular.fire,
                size: 14,
                color: Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '连续阅读',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$days',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          Text('天', style: tt.labelLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.books,
                size: 10,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('读过 $totalBooks 本书', style: tt.labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reading Trend ──

  Widget _buildReadingTrendChart(
    ColorScheme cs,
    TextTheme tt,
    List<ReadingStats> records,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读趋势',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: records.length < 2
                  ? const Center(child: Text('数据不足'))
                  : _buildLineChart(cs, tt, records),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildLineChart(
    ColorScheme cs,
    TextTheme tt,
    List<ReadingStats> records,
  ) {
    final spots = records
        .asMap()
        .entries
        .map(
          (e) => FlSpot(
            e.key.toDouble(),
            e.value.readingTimeSeconds.toInt() / 60.0,
          ),
        )
        .toList();
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (v, m) {
                final idx = v.toInt();
                if (idx < 0 || idx >= records.length) return const SizedBox();
                if (records.length > 14 && idx % 7 != 0) {
                  return const SizedBox();
                }
                final day = DateTime.parse(records[idx].date);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${day.month}/${day.day}', style: tt.labelSmall),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  // ── Weekly Heatmap ──

  Widget _buildWeeklyHeatmap(ColorScheme cs, List<ReadingStats> records) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '阅读热力图',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _weekdayLabels.map((label) {
                return SizedBox(
                  width: 32,
                  child: Column(
                    children: [
                      for (int w = 0; w < 4; w++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _heatmapColor(
                              cs,
                              _getWeekMinutes(w, label, records),
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 400.ms);
  }

  int _getWeekMinutes(
    int weekOffset,
    String weekdayLabel,
    List<ReadingStats> records,
  ) {
    var total = 0;
    for (final r in records) {
      try {
        final dt = DateTime.parse(r.date);
        if (_weekdayLabels[dt.weekday - 1] == weekdayLabel) {
          total += r.readingTimeSeconds.toInt();
        }
      } catch (e) {
        Logging.error('解析阅读日期失败', exception: e);
      }
    }
    return total;
  }

  Color _heatmapColor(ColorScheme cs, int seconds) {
    if (seconds == 0) return cs.surfaceContainerHighest.withValues(alpha: 0.4);
    if (seconds < 600) return cs.primary.withValues(alpha: 0.15);
    if (seconds < 1800) return cs.primary.withValues(alpha: 0.35);
    if (seconds < 3600) return cs.primary.withValues(alpha: 0.55);
    return cs.primary.withValues(alpha: 0.75);
  }

  // ── Vocabulary Stats ──

  Widget _buildVocabStats(
    ColorScheme cs,
    TextTheme tt,
    int vocabNew,
    int vocabLearning,
    int vocabMastered,
    int vocabIgnored,
    int vocabTotal,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: cs.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生词统计',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _vocabStatBar(
                  cs,
                  tt,
                  '未学',
                  vocabNew,
                  vocabTotal,
                  cs.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                _vocabStatBar(
                  cs,
                  tt,
                  '学习中',
                  vocabLearning,
                  vocabTotal,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _vocabStatBar(
                  cs,
                  tt,
                  '已掌握',
                  vocabMastered,
                  vocabTotal,
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _vocabStatBar(
                  cs,
                  tt,
                  '已忽略',
                  vocabIgnored,
                  vocabTotal,
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }

  Widget _vocabStatBar(
    ColorScheme cs,
    TextTheme tt,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final ratio = total > 0 ? count / total : 0.0;
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60 * ratio.clamp(0.02, 1.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(label, style: tt.labelSmall),
        ],
      ),
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
          final labels = const ['本日', '本周', '本月', '全年'];
          return GestureDetector(
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
