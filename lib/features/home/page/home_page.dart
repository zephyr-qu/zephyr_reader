import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

/// 首页 - 展示阅读概览、最近阅读、推荐等内容
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);
    final isTabletOrDesktop = deviceType != DeviceType.phone;

    return Scaffold(
      appBar: _buildAppBar(context, theme),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: pagePadding,
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTabletOrDesktop)
                      ..._buildTabletLayout(context, theme)
                    else
                      ..._buildPhoneLayout(context, theme),
                    SizedBox(height: LayoutBreakpoints.getSpacing(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Zephyr'),
        ],
      ),
      centerTitle: false,
      actions: [
        _buildAppBarButton(
          context,
          icon: Icons.search_rounded,
          label: '搜索',
          onTap: () => context.pushNamed(RouteNames.search),
        ),
        _buildAppBarButton(
          context,
          icon: Icons.notifications_outlined,
          label: '通知',
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('暂无新通知')));
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 22),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  /// 手机布局
  List<Widget> _buildPhoneLayout(BuildContext context, ThemeData theme) {
    return [
      _buildWelcomeCard(
        context,
      ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      _buildSectionHeader(
        context,
        title: '最近阅读',
        actionLabel: '查看全部',
        onActionPressed: () => context.pushNamed(RouteNames.bookshelf),
      ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildRecentReading(
        context,
      ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      _buildSectionHeader(
        context,
        title: '阅读统计',
        actionLabel: '详情',
        onActionPressed: () => context.pushNamed(RouteNames.statistics),
      ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildReadingStats(
        context,
      ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      _buildSectionHeader(
        context,
        title: '为你推荐',
        actionLabel: '更多',
        onActionPressed: () => context.pushNamed(RouteNames.search),
      ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildRecommendations(
        context,
      ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
    ];
  }

  /// 平板/桌面布局
  List<Widget> _buildTabletLayout(BuildContext context, ThemeData theme) {
    final spacing = LayoutBreakpoints.getSpacing(context);

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeCard(context)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.05, end: 0),
                SizedBox(height: spacing),
                _buildSectionHeader(
                  context,
                  title: '最近阅读',
                  actionLabel: '查看全部',
                  onActionPressed: () =>
                      context.pushNamed(RouteNames.bookshelf),
                ).animate().fadeIn(delay: 100.ms, duration: 500.ms),
                SizedBox(height: spacing / 2),
                _buildRecentReading(
                  context,
                ).animate().fadeIn(delay: 200.ms, duration: 500.ms),
              ],
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReadingStats(
                  context,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                SizedBox(height: spacing),
                _buildSectionHeader(
                  context,
                  title: '为你推荐',
                  actionLabel: '更多',
                  onActionPressed: () => context.pushNamed(RouteNames.search),
                ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                SizedBox(height: spacing / 2),
                _buildRecommendations(
                  context,
                ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required VoidCallback onActionPressed,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onActionPressed,
          child: Text(
            actionLabel,
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 6) {
      greeting = '夜深';
    } else if (hour < 12) {
      greeting = '早上';
    } else if (hour < 14) {
      greeting = '中午';
    } else if (hour < 18) {
      greeting = '下午';
    } else {
      greeting = '晚上';
    }

    return GradientCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: Colors.white,
                  size: 28,
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting好',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '开始阅读吧',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '阅读是心灵的旅行，在字里行间发现更广阔的世界',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.pushNamed(RouteNames.bookshelf),
                  icon: const Icon(Icons.book),
                  label: const Text('我的书架'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate().scale(
                delay: 300.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pushNamed(RouteNames.search),
                  icon: const Icon(Icons.explore),
                  label: const Text('发现好书'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate().scale(
                delay: 400.ms,
                duration: 400.ms,
                curve: Curves.easeOutBack,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReading(BuildContext context) {
    final theme = Theme.of(context);

    final recentBooks = [
      {'title': '三体', 'author': '刘慈欣', 'progress': 0.65, 'chapter': '第 45 章'},
      {'title': '活着', 'author': '余华', 'progress': 0.30, 'chapter': '第 12 章'},
    ];

    if (recentBooks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  '还没有开始阅读',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pushNamed(RouteNames.bookshelf),
                  child: const Text('去书架'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentBooks.map((book) {
        final progressVal = book['progress'] as double;
        final progress = (progressVal * 100).toInt();
        return ProgressCard(
          title: book['title'] as String,
          subtitle: book['author'] as String,
          progress: progressVal,
          progressLabel: '$progress%',
          icon: Icons.book,
          onTap: () => context.pushNamed(RouteNames.bookshelf),
        );
      }).toList(),
    );
  }

  Widget _buildReadingStats(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            StatCard(
              label: '阅读天数',
              value: '12',
              icon: Icons.calendar_today,
              color: theme.colorScheme.primary,
            ),
            _buildDivider(theme),
            StatCard(
              label: '阅读时长',
              value: '8.5h',
              icon: Icons.timer,
              color: theme.colorScheme.secondary,
            ),
            _buildDivider(theme),
            StatCard(
              label: '已读书籍',
              value: '3',
              icon: Icons.book_online,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.outline.withValues(alpha: 0),
            theme.colorScheme.outline.withValues(alpha: 0.3),
            theme.colorScheme.outline.withValues(alpha: 0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final theme = Theme.of(context);

    final recommendations = [
      {'title': '百年孤独', 'author': '加西亚·马尔克斯'},
      {'title': '1984', 'author': '乔治·奥威尔'},
      {'title': '小王子', 'author': '圣埃克苏佩里'},
    ];

    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recommendations.length,
        separatorBuilder: (context, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final book = recommendations[index];
          return SizedBox(
                width: 170,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.pushNamed(RouteNames.search),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primaryContainer,
                                  theme.colorScheme.tertiaryContainer,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.auto_stories,
                                size: 56,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['title'] as String,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                book['author'] as String,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: (100 * index).ms, duration: 400.ms)
              .then()
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              );
        },
      ),
    );
  }
}
