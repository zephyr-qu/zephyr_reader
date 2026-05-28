import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// 首屏 Hero 区域的渐变背景
final _heroGradient = LinearGradient(
  colors: [
    DesignTokens.warmAccent,
    DesignTokens.warmAccent.withValues(alpha: 0.7),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(
      DesignTokens.spacing(Spacing.md),
      DesignTokens.spacing(Spacing.lg),
      DesignTokens.spacing(Spacing.md),
      0,
    );
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: adaptiveScrollPhysics(context),
          slivers: [
            SliverPadding(
              padding: padding,
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
              padding: padding,
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
              padding: padding,
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
              padding: padding,
              sliver: const SliverToBoxAdapter(
                child: SkeletonCard(height: 100, lineCount: 0, borderRadius: 8),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
            ),
            SliverPadding(
              padding: padding,
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
}

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

// 首页主页面，HookWidget 驱动状态
class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取 VM 实例
    final vm = useMemoized(() => HomeViewModel());

    // 订阅 VM 的信号（Widget 卸载时自动取消订阅）
    final recentBooks = useExistingSignal(vm.recentBooks);
    final dailyRecords = useExistingSignal(vm.dailyRecords);

    // 获取主题和本地化
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 问候语逻辑保持不变
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? l10n.greetingLateNight
        : hour < 12
        ? l10n.greetingMorning
        : hour < 14
        ? l10n.greetingNoon
        : hour < 18
        ? l10n.greetingAfternoon
        : l10n.greetingEvening;

    return recentBooks.value.map(
      loading: () => const _HomeLoadingSkeleton(),
      error: (error, stack) => _buildErrorView(
        context: context,
        theme: theme,
        l10n: l10n,
        errorMessage: error.toString(),
        onRetry: () => vm.refresh(),
      ),
      data: (books) {
        // 同时检查 dailyRecords 的状态
        return dailyRecords.value.map(
          loading: () => const _HomeLoadingSkeleton(),
          error: (error, stack) => _buildErrorView(
            context: context,
            theme: theme,
            l10n: l10n,
            errorMessage: error.toString(),
            onRetry: () => vm.refresh(),
          ),
          data: (records) => _buildContent(
            context,
            theme,
            l10n,
            greeting,
            books.isNotEmpty ? books[0] : null,
            books,
            records,
            vm.refresh,
          ),
        );
      },
    );
  }

  Widget _buildErrorView({
    required BuildContext context,
    required ThemeData theme,
    required AppLocalizations l10n,
    required String errorMessage,
    required VoidCallback onRetry,
  }) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(
                    PhosphorIconsRegular.arrowClockwise,
                    size: 18,
                  ),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 组装各 Sliver 子组件
  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    String greeting,
    Book? currentBook,
    List<Book> books,
    List<ReadingStats> records,
    VoidCallback onRefresh,
  ) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: adaptiveScrollPhysics(context),
          slivers: [
            _buildHeaderSliver(context, theme, greeting),
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
              sliver: SliverToBoxAdapter(
                child: _buildReadingTrend(context, theme, records),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
            ),
            _buildRecentSliver(context, theme, books),
          ],
        ),
      ),
    );
  }

  // 顶部问候语 + "继续阅读" 标题
  SliverPadding _buildHeaderSliver(
    BuildContext context,
    ThemeData theme,
    String greeting,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.continueReading,
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

  // 最近阅读的横向滑动列表（空态引导）
  SliverPadding _buildRecentSliver(
    BuildContext context,
    ThemeData theme,
    List<Book> recentBooks,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
              l10n.recentReading,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: recentBooks.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noReadingRecord,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentBooks.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        return _recentCard(context, recentBooks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 每日一句：从 _quotes 列表中按日期取模选取
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

  // 阅读趋势折线图（最近 7 天各日阅读分钟数）
  Widget _buildReadingTrend(
    BuildContext context,
    ThemeData theme,
    List<ReadingStats> dailyRecords,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final df = DateFormat('E', locale);
    final dateMap = <String, double>{};
    for (final r in dailyRecords) {
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
          l10n.readingTrend,
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
                      if (idx < 0 || idx > 6) {
                        return const SizedBox.shrink();
                      }
                      final d = now.subtract(Duration(days: 6 - idx));
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          df.format(d),
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

  // 有书时展示的继续阅读 Hero 卡片
  Widget _buildHero(BuildContext context, ThemeData theme, Book book) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
      decoration: BoxDecoration(
        gradient: _heroGradient,
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
                  book.author ?? l10n.unknownAuthor,
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
                    child: Text(
                      l10n.continueReading,
                      style: const TextStyle(
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

  // 无书时展示的引导 Hero 卡片
  Widget _buildEmptyHero(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.lg)),
      decoration: BoxDecoration(
        gradient: _heroGradient,
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
                Text(
                  l10n.startReadingJourney,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                Text(
                  l10n.exploreNewWorld,
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
            child: Text(
              l10n.goToBookshelf,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // 单本最近阅读卡片（封面占位图 + 标题）
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
