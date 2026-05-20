import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

const _quotes = [
  (text: '读书破万卷，下笔如有神。', author: '杜甫'),
  (text: '读万卷书，行万里路。', author: '董其昌'),
  (text: '书山有路勤为径，学海无涯苦作舟。', author: '韩愈'),
  (text: '问渠那得清如许？为有源头活水来。', author: '朱熹'),
  (text: '立身以立学为先，立学以读书为本。', author: '欧阳修'),
  (text: '书籍是人类进步的阶梯。', author: '高尔基'),
  (text: '读一本好书，就是和许多高尚的人谈话。', author: '笛卡尔'),
  (text: '学而不思则罔，思而不学则殆。', author: '孔子'),
  (text: '温故而知新，可以为师矣。', author: '孔子'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = getIt<RustStorageService>();
  final _statsService = getIt<ReadingStatsService>();
  List<Book> _recentBooks = [];
  List<ReadingStats> _dailyRecords = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _storage.getRecentlyReadBooks(4),
        _statsService.getDailyRecords(days: 7),
      ]);
      if (mounted) {
        setState(() {
          _recentBooks = results[0] as List<Book>;
          _dailyRecords = results[1] as List<ReadingStats>;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 6) {
      greeting = '夜深了';
    } else if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 14) {
      greeting = '中午好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    final currentBook = _recentBooks.isNotEmpty ? _recentBooks[0] : null;

    if (!_loaded) return _buildLoadingSkeleton();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: adaptiveScrollPhysics(context),
          slivers: [
            _buildHeaderSliver(theme, greeting),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: SliverToBoxAdapter(child: _buildDailyQuote(theme)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: currentBook != null
                    ? _buildHero(context, theme, currentBook)
                    : _buildEmptyHero(context, theme),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: SliverToBoxAdapter(child: _buildReadingTrend(theme)),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
            ),
            _buildRecentSliver(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: adaptiveScrollPhysics(context),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: const SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonWidget(height: 13, width: 60, borderRadius: 3),
                    SizedBox(height: 18),
                    SkeletonWidget(height: 26, width: 120, borderRadius: 4),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: const SliverToBoxAdapter(
                child: SkeletonCard(
                  height: 52,
                  lineCount: 1,
                  lineHeight: 14,
                  borderRadius: 8,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonWidget(
                      height: 13,
                      width: 80,
                      borderRadius: 3,
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                    const SkeletonCard(
                      height: 180,
                      lineCount: 0,
                      borderRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.lg),
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: const SliverToBoxAdapter(
                child: SkeletonCard(height: 100, lineCount: 0, borderRadius: 8),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DesignTokens.spacing(Spacing.md),
                0,
                DesignTokens.spacing(Spacing.md),
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonWidget(
                      height: 13,
                      width: 80,
                      borderRadius: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, _) => const SkeletonCard(
                          width: 100,
                          height: 140,
                          lineCount: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildHeaderSliver(ThemeData theme, String greeting) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.md),
        DesignTokens.spacing(Spacing.lg),
        DesignTokens.spacing(Spacing.md),
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '继续阅读',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverPadding _buildRecentSliver(ThemeData theme) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.md),
        0,
        DesignTokens.spacing(Spacing.md),
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近阅读',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: _recentBooks.isEmpty
                  ? Center(
                      child: Text(
                        '暂无阅读记录',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentBooks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        return _recentCard(context, _recentBooks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyQuote(ThemeData theme) {
    final day = DateTime.now().day;
    final quote = _quotes[day % _quotes.length];
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: DesignTokens.warmAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    quote.author,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DesignTokens.warmAccent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingTrend(ThemeData theme) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dateMap = <String, double>{};
    for (final r in _dailyRecords) {
      dateMap[r.date] = r.readingTimeSeconds.toDouble() / 60.0;
    }
    final now = DateTime.now();
    double maxVal = 0;
    final spots = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final val = dateMap[key] ?? 0;
      if (val > maxVal) maxVal = val;
      return FlSpot(i.toDouble(), val);
    });
    final ceiling = maxVal > 0 ? (maxVal * 1.3).ceilToDouble() : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本周阅读趋势',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: DesignTokens.spacing(Spacing.sm)),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: theme.colorScheme.primary,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
              ],
              lineTouchData: const LineTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
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
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= weekdays.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          weekdays[idx],
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: ceiling,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(BuildContext context, ThemeData theme, Book book) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.warmAccent,
            DesignTokens.warmAccent.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              DesignTokens.radius(RadiusSize.sm),
            ),
            child: Container(
              width: 72,
              height: 100,
              color: Colors.white.withValues(alpha: 0.3),
              child: Icon(
                PhosphorIconsRegular.bookOpenText,
                size: 28,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                Text(
                  book.author ?? '未知作者',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton(
                    onPressed: () => context.pushNamed(RouteNames.bookshelf),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DesignTokens.warmAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radius(RadiusSize.sm),
                        ),
                      ),
                    ),
                    child: const Text(
                      '继续阅读',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHero(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.lg)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.warmAccent,
            DesignTokens.warmAccent.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.bookOpenText,
            size: 36,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          SizedBox(width: DesignTokens.spacing(Spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '开始你的阅读之旅',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                Text(
                  '打开一本书，探索新的世界',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => context.pushNamed(RouteNames.bookshelf),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: DesignTokens.warmAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  DesignTokens.radius(RadiusSize.sm),
                ),
              ),
            ),
            child: const Text('去书库', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(BuildContext context, Book book) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.bookshelf),
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.sm),
              ),
              child: Container(
                width: 72,
                height: 96,
                color: theme.colorScheme.primaryContainer,
                child: Icon(
                  PhosphorIconsRegular.bookOpenText,
                  size: 24,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.sm)),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
