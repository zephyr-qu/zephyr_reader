import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as rust_book;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as rust_stats;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  GlobalStats? _globalStats;
  List<ReadingStats> _dailyRecords = [];
  List<Book> _recentBooks = [];
  int _vocabNew = 0;
  int _vocabLearning = 0;
  int _vocabMastered = 0;
  int _vocabIgnored = 0;
  bool _loaded = false;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        rust_stats.getGlobalReadingStats(),
        rust_stats.getReadingStatsByDaysWithFill(days: 30),
        rust_book.listRecentlyOpenedBooks(limit: BigInt.from(6)),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.new_),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.learning),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.mastered),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.ignored),
      ]);
      if (mounted) {
        setState(() {
          _globalStats = results[0] as GlobalStats;
          _dailyRecords = results[1] as List<ReadingStats>;
          _recentBooks = results[2] as List<Book>;
          _vocabNew = (results[3] as List<Vocab>).length;
          _vocabLearning = (results[4] as List<Vocab>).length;
          _vocabMastered = (results[5] as List<Vocab>).length;
          _vocabIgnored = (results[6] as List<Vocab>).length;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          '年度阅览报告',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildRingOverview(cs),
                const SizedBox(height: 32),
                _buildDistributionPie(cs),
                const SizedBox(height: 32),
                _buildVocabRow(cs),
                const SizedBox(height: 32),
                _buildHeatmap(cs),
                const SizedBox(height: 32),
                _buildTrend(cs),
                const SizedBox(height: 32),
                _buildCurrentReading(cs),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  // ==================== Ring Progress Cards ====================

  Widget _buildRingOverview(ColorScheme cs) {
    final stats = _globalStats;
    final totalHours = (stats?.totalReadingTimeSeconds ?? 0) ~/ 3600;
    const maxHours = 200;
    final booksDone = stats?.booksCompletedCount ?? 0;
    const maxBooks = 50;
    final vocabTotal = _vocabMastered + _vocabLearning;
    const maxVocab = 500;
    final streak = stats?.consecutiveReadingDays ?? 0;
    const maxStreak = 365;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                '阅读概览',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _ringCard(
                    cs,
                    totalHours.toDouble(),
                    maxHours.toDouble(),
                    '阅读时长',
                    '小时',
                    DesignTokens.primary,
                    PhosphorIconsRegular.clock,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ringCard(
                    cs,
                    booksDone.toDouble(),
                    maxBooks.toDouble(),
                    '读完书籍',
                    '本',
                    DesignTokens.success,
                    PhosphorIconsRegular.bookOpen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ringCard(
                    cs,
                    vocabTotal.toDouble(),
                    maxVocab.toDouble(),
                    '生词学习',
                    '词',
                    const Color(0xFF8B5CF6),
                    PhosphorIconsRegular.bookmarkSimple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ringCard(
                    cs,
                    streak.toDouble(),
                    maxStreak.toDouble(),
                    '连续天数',
                    '天',
                    DesignTokens.warmAccent,
                    PhosphorIconsRegular.fire,
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _ringCard(
    ColorScheme cs,
    double value,
    double max,
    String label,
    String unit,
    Color color,
    IconData icon,
  ) {
    final ratio = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CustomPaint(
              painter: _RingProgressPainter(
                progress: ratio,
                color: color,
                backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                strokeWidth: 4.5,
              ),
              child: Center(child: Icon(icon, size: 18, color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: value),
                  duration: 1200.ms,
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) {
                    final d = v >= 1000
                        ? '${(v / 1000).toStringAsFixed(1)}k'
                        : v.toInt().toString();
                    return Text(
                      d,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  '$label ($unit)',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Distribution Pie ====================

  Widget _buildDistributionPie(ColorScheme cs) {
    final stats = _globalStats;
    final totalBooks = stats?.totalBooksCount ?? 0;
    final completed = stats?.booksCompletedCount ?? 0;
    final reading = (stats?.booksReadCount ?? 0) - completed;
    final remaining = totalBooks - (stats?.booksReadCount ?? 0);

    final sections = <PieChartSectionData>[];
    final legendItems = <_LegendItem>[];
    final data = <(String, int, Color)>[
      ('已读完', completed.max(0), DesignTokens.success),
      ('在读中', reading.max(0), DesignTokens.primary),
      ('待阅读', remaining.max(0), cs.onSurface.withValues(alpha: 0.15)),
    ];
    for (final entry in data) {
      if (entry.$2 > 0) {
        sections.add(
          PieChartSectionData(
            value: entry.$2.toDouble(),
            color: entry.$3,
            radius: 40,
            titleStyle: const TextStyle(fontSize: 0),
          ),
        );
        legendItems.add(_LegendItem(entry.$1, entry.$2, entry.$3));
      }
    }
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: cs.onSurface.withValues(alpha: 0.06),
          radius: 40,
        ),
      );
    }

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                '书籍分布',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 28,
                        sectionsSpace: 2,
                        borderData: FlBorderData(show: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: legendItems
                          .map((item) => _legendRow(item, cs))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _legendRow(_LegendItem item, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            '${item.count}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Vocab Stats Row ====================

  Widget _buildVocabRow(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                '生词统计',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _vocabBadge(
                    cs,
                    '新词',
                    _vocabNew,
                    const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _vocabBadge(
                    cs,
                    '学习中',
                    _vocabLearning,
                    const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _vocabBadge(
                    cs,
                    '已掌握',
                    _vocabMastered,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _vocabBadge(
                    cs,
                    '已忽略',
                    _vocabIgnored,
                    cs.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _vocabBadge(ColorScheme cs, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: count.toDouble()),
            duration: 1200.ms,
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              return Text(
                v.toInt().toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Heatmap ====================

  Widget _buildHeatmap(ColorScheme cs) {
    final today = DateTime.now();
    final records = _dailyRecords;
    final recordMap = <String, int>{};
    for (final r in records) {
      recordMap[r.date] = r.readingTimeSeconds ~/ 60;
    }
    final cells = <List<int>>[];
    for (var w = 0; w < 4; w++) {
      final week = <int>[];
      for (var d = 0; d < 7; d++) {
        final date = today.subtract(Duration(days: (3 - w) * 7 + (6 - d)));
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        week.add(recordMap[key] ?? 0);
      }
      cells.add(week);
    }
    final activeDays = records.where((r) => r.readingTimeSeconds > 0).length;

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Text(
                    '阅读足迹',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '近28天 · $activeDays 天活跃',
                      style: const TextStyle(
                        fontSize: 10,
                        color: DesignTokens.warmAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if ((_globalStats?.consecutiveReadingDays ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const Icon(
                            PhosphorIconsRegular.fire,
                            size: 18,
                            color: DesignTokens.warmAccent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '已连续阅读 ${_globalStats!.consecutiveReadingDays} 天',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: DesignTokens.warmAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _stampLegend(cs, '少', _stampColors(cs)[0]),
                      ..._stampColors(
                        cs,
                      ).skip(1).map((c) => _stampLegend(cs, '', c)),
                      _stampLegend(cs, '多', _stampColors(cs).last),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: _weekdayLabels
                            .map(
                              (l) => Container(
                                height: 22,
                                alignment: Alignment.center,
                                child: Text(
                                  l,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: cs.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: List.generate(
                            4,
                            (w) => Expanded(
                              child: Column(
                                children: List.generate(7, (d) {
                                  final mins = cells[w][d];
                                  return Container(
                                    margin: const EdgeInsets.all(1.5),
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: _stampColorFor(cs, mins),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  List<Color> _stampColors(ColorScheme cs) => [
    cs.primary.withValues(alpha: 0.08),
    cs.primary.withValues(alpha: 0.2),
    cs.primary.withValues(alpha: 0.4),
    cs.primary.withValues(alpha: 0.65),
    cs.primary,
  ];

  Color _stampColorFor(ColorScheme cs, int minutes) {
    final colors = _stampColors(cs);
    if (minutes == 0) return Colors.transparent;
    if (minutes < 15) return colors[0];
    if (minutes < 30) return colors[1];
    if (minutes < 60) return colors[2];
    if (minutes < 90) return colors[3];
    return colors[4];
  }

  Widget _stampLegend(ColorScheme cs, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (label.isNotEmpty) const SizedBox(width: 3),
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== Trend Bar Chart ====================

  Widget _buildTrend(ColorScheme cs) {
    final records = _dailyRecords;
    if (records.isEmpty) return const SizedBox.shrink();
    final minutes = records.map((r) => r.readingTimeSeconds / 60.0).toList();
    final maxY = minutes
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, double.infinity);
    final days = records.map((r) {
      final parts = r.date.split('-');
      return '${int.parse(parts[1])}/${int.parse(parts[2])}';
    }).toList();

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Text(
                '阅读节奏',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY + 10,
                    barTouchData: const BarTouchData(enabled: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.08),
                        strokeWidth: 0.5,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 16,
                          interval: 5,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) {
                              return const SizedBox.shrink();
                            }
                            if (idx % 5 != 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                days[idx],
                                style: TextStyle(
                                  fontSize: 9,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(minutes.length, (i) {
                      final isToday = i == minutes.length - 1;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: minutes[i].clamp(0, double.infinity),
                            color: isToday
                                ? DesignTokens.warmAccent
                                : cs.primary,
                            width: 6,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  // ==================== Current Reading ====================

  Widget _buildCurrentReading(ColorScheme cs) {
    final books = _recentBooks;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 14),
              child: Row(
                children: [
                  Text(
                    '正在阅读',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: DesignTokens.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '最近打开',
                      style: TextStyle(
                        fontSize: 10,
                        color: DesignTokens.warmAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (books.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: cs.onSurface.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        PhosphorIconsRegular.bookOpen,
                        size: 32,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '还没有阅读记录',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...books.map((book) => _recentBookTile(cs, book)),
          ],
        )
        .animate()
        .slideX(begin: 0.05, duration: 400.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  Widget _recentBookTile(ColorScheme cs, Book book) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(PhosphorIconsRegular.book, size: 18, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  book.author ?? '未知作者',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            book.status == BookStatus.completed ? '已读完' : '阅读中',
            style: TextStyle(
              fontSize: 11,
              color: book.status == BookStatus.completed
                  ? DesignTokens.success
                  : DesignTokens.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _RingProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    paint.color = backgroundColor;
    canvas.drawCircle(center, radius, paint);

    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingProgressPainter old) => old.progress != progress;
}

class _LegendItem {
  final String label;
  final int count;
  final Color color;
  const _LegendItem(this.label, this.count, this.color);
}

extension on int {
  int max(int other) => this > other ? this : other;
}
