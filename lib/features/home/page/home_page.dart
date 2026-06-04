import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'dart:io';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/features/home/page/home_quotes.dart';
import 'package:zephyr_reader/features/home/page/home_reading_trend.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// 首屏 Hero 区域的渐变背景（按主题亮度自适应）
LinearGradient _heroGradientFor(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  final baseColor = isDark
      ? Color.lerp(DesignTokens.warmAccent, Colors.black, 0.4)!
      : DesignTokens.warmAccent;
  return LinearGradient(
    colors: [
      baseColor,
      baseColor.withValues(alpha: 0.7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Hero 卡片：有书/空态共用同一布局结构
class _HeroCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _HeroCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
      decoration: BoxDecoration(
        gradient: _heroGradientFor(theme),
        borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          SizedBox(width: DesignTokens.spacing(Spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton(
                    onPressed: onPressed,
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
                      buttonLabel,
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
}

final _heroCoverPlaceholder = Container(
  color: Colors.white.withValues(alpha: 0.3),
  child: Icon(
    PhosphorIconsRegular.bookOpenText,
    size: 28,
    color: Colors.white.withValues(alpha: 0.6),
  ),
);
// 错误视图
class _HomeErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _HomeErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
}

// 顶部问候语 + "继续阅读" 标题
class _HomeHeaderSliver extends StatelessWidget {
  final String greeting;

  const _HomeHeaderSliver({required this.greeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
}

// 单本最近阅读卡片（封面占位图 + 标题）
class _RecentBookCard extends StatelessWidget {
  final Book book;

  const _RecentBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.pushNamed(
        RouteNames.reader,
        pathParameters: {
          'bookId': book.bookId,
          'chapterId': '0',
        },
      ),
      borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.sm)),
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.sm),
              ),
              child: SizedBox(
                width: 72,
                height: 96,
                child: book.coverPath != null
                    ? Image.file(
                        File(resolveCoverPath(book.coverPath!)!),
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            PhosphorIconsRegular.bookOpenText,
                            size: 24,
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                          PhosphorIconsRegular.bookOpenText,
                          size: 24,
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
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

// Hero 卡片：有书/空态（通过 book 参数区分）
class _HeroSection extends StatelessWidget {
  final Book? book;

  const _HeroSection({required this.book});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasBook = book != null;
    return _HeroCard(
      leading: hasBook
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.sm),
              ),
              child: SizedBox(
                width: 72,
                height: 100,
                child: book!.coverPath != null
                    ? Image.file(
                        File(resolveCoverPath(book!.coverPath!)!),
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        errorBuilder: (_, _, _) => _heroCoverPlaceholder,
                      )
                    : _heroCoverPlaceholder,
              ),
            )
          : Icon(
              PhosphorIconsRegular.bookOpenText,
              size: 36,
              color: Colors.white.withValues(alpha: 0.9),
            ),
      title: hasBook ? book!.title : l10n.startReadingJourney,
      subtitle: hasBook
          ? (book!.author ?? l10n.unknownAuthor)
          : l10n.exploreNewWorld,
      buttonLabel: hasBook ? l10n.continueReading : l10n.goToBookshelf,
      onPressed: hasBook
          ? () => context.pushNamed(
                RouteNames.reader,
                pathParameters: {
                  'bookId': book!.bookId,
                  'chapterId': '0',
                },
              )
          : () => context.pushNamed(RouteNames.bookshelf),
    );
  }
}



class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => HomeViewModel());
    useFutureSignal(() => vm.loadData());
    final AsyncState<List<Book>> recentBooks = useSignalValue(vm.recentBooks);
    final AsyncState<List<ReadingStats>> dailyRecords = useSignalValue(
      vm.dailyRecords,
    );

    // 获取主题和本地化
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final greeting = useMemoized(() {
      final hour = DateTime.now().hour;
      return hour < 6
          ? l10n.greetingLateNight
          : hour < 12
          ? l10n.greetingMorning
          : hour < 14
          ? l10n.greetingNoon
          : hour < 18
          ? l10n.greetingAfternoon
          : l10n.greetingEvening;
    }, [DateTime.now().hour]);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              physics: adaptiveScrollPhysics(
                context,
              ).applyTo(const AlwaysScrollableScrollPhysics()),
              slivers: [
            _HomeHeaderSliver(greeting: greeting),
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
                child: recentBooks.map(
                  loading: () => const SizedBox.shrink(),
                  error: (Object error, StackTrace? stack) => _HomeErrorView(
                    errorMessage: error.toString(),
                    onRetry: () => vm.loadData(),
                  ),
                  data: (List<Book> value) => _HeroSection(
                    book: value.isNotEmpty ? value[0] : null,
                  ),
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
                child: dailyRecords.map(
                  loading: () => const SizedBox.shrink(),
                  error: (Object error, StackTrace? stack) => _HomeErrorView(
                    errorMessage: error.toString(),
                    onRetry: () => vm.loadData(),
                  ),
                  data: (List<ReadingStats> value) =>
                      ReadingTrend(dailyRecords: value),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.only(top: DesignTokens.spacing(Spacing.xl)),
            ),
            recentBooks.map(
              loading: () =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (Object error, StackTrace? stack) => SliverToBoxAdapter(
                child: _HomeErrorView(
                  errorMessage: error.toString(),
                  onRetry: () => vm.loadData(),
                ),
              ),
              data: (List<Book> value) =>
                  _buildRecentSliver(context, theme, value),
            ),
            ],
          ),
        ),
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
                        return _RecentBookCard(book: recentBooks[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }


}
