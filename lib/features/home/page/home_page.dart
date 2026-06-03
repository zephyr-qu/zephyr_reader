import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/home/page/home_quotes.dart';
import 'package:zephyr_reader/features/home/page/home_reading_trend.dart';

// 首屏 Hero 区域的渐变背景
final _heroGradient = LinearGradient(
  colors: [
    DesignTokens.warmAccent,
    DesignTokens.warmAccent.withValues(alpha: 0.7),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);



class HomePage extends HookWidget {
  late final HomeViewModel vm = getIt<HomeViewModel>();
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 订阅 VM 的信号
    final AsyncState<List<Book>> recentBooks = useSignalValue(vm.recentBooks);
    final AsyncState<List<ReadingStats>> dailyRecords = useSignalValue(
      vm.dailyRecords,
    );

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

    return recentBooks.map(
      loading: () => const SizedBox.shrink(),
      error: (Object error, StackTrace? stack) => _buildErrorView(
        context: context,
        theme: theme,
        l10n: l10n,
        errorMessage: error.toString(),
        onRetry: () => vm.refresh(),
      ),
      data: (books) {
        // 同时检查 dailyRecords 的状态
        return dailyRecords.map(
          loading: () => const SizedBox.shrink(),
          error: (Object error, StackTrace? stack) => _buildErrorView(
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
        child: RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: CustomScrollView(
            physics: adaptiveScrollPhysics(context).applyTo(
              const AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              _buildHeaderSliver(context, theme, greeting),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  DesignTokens.spacing(Spacing.md),
                  DesignTokens.spacing(Spacing.lg),
                  DesignTokens.spacing(Spacing.md),
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: buildDailyQuote(context, theme),
                ),
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
                  child: buildReadingTrend(context, theme, records),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
              ),
              _buildRecentSliver(context, theme, books),
            ],
          ),
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
                  style: const TextStyle(fontSize: 12, color: Colors.white),
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
                  style: const TextStyle(fontSize: 13, color: Colors.white),
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
