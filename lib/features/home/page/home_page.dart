import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/features/home/page/widget/home_quotes.dart';
import 'package:zephyr_reader/features/home/page/widget/home_reading_trend.dart';
import 'package:zephyr_reader/features/home/page/widget/home_error_view.dart';
import 'package:zephyr_reader/features/home/page/widget/home_header_sliver.dart';
import 'package:zephyr_reader/features/home/page/widget/home_hero_section.dart';
import 'package:zephyr_reader/features/home/page/widget/home_recent_list.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 首页。
///
/// 展示最近阅读书籍、阅读趋势、每日语录等概览信息。
/// 使用 [HomeViewModel] 加载书籍和阅读统计数据。
class HomePage extends HookWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => HomeViewModel());
    useEffect(() {
      vm.loadData();
      return null;
    }, []);
    final AsyncState<List<Book>> recentBooks = useSignalValue(vm.recentBooks);
    final AsyncState<List<ReadingStats>> dailyRecords = useSignalValue(
      vm.dailyRecords,
    );

    // 获取本地化
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth >= LayoutBreakpoints.expandedMin
                ? LayoutBreakpoints.expandedMin
                : LayoutBreakpoints.compactMax;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: CustomScrollView(
                  physics: adaptiveScrollPhysics(
                    context,
                  ).applyTo(const AlwaysScrollableScrollPhysics()),
                  slivers: [
                    HomeHeaderSliver(greeting: greeting),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.md.value,
                        Spacing.lg.value,
                        Spacing.md.value,
                        0,
                      ),
                      sliver: const SliverToBoxAdapter(child: DailyQuote()),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.md.value,
                        Spacing.md.value,
                        Spacing.md.value,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: recentBooks.map(
                          loading: () => const SizedBox.shrink(),
                          error: (dynamic error, dynamic stack) =>
                              HomeErrorView(
                                errorMessage: error.toString(),
                                onRetry: () => vm.loadData(),
                              ),
                          data: (List<Book> value) => HomeHeroSection(
                            book: value.isNotEmpty ? value[0] : null,
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Spacing.md.value,
                        Spacing.lg.value,
                        Spacing.md.value,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: dailyRecords.map(
                          loading: () => const SizedBox.shrink(),
                          error: (dynamic error, dynamic stack) =>
                              HomeErrorView(
                                errorMessage: error.toString(),
                                onRetry: () => vm.loadData(),
                              ),
                          data: (List<ReadingStats> value) =>
                              ReadingTrend(dailyRecords: value),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: Spacing.xl.value,
                      ),
                    ),
                    recentBooks.map(
                      loading: () =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (dynamic error, dynamic stack) =>
                          SliverToBoxAdapter(
                            child: HomeErrorView(
                              errorMessage: error.toString(),
                              onRetry: () => vm.loadData(),
                            ),
                          ),
                      data: (List<Book> value) => SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          Spacing.md.value,
                          0,
                          Spacing.md.value,
                          0,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: HomeRecentList(books: value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
