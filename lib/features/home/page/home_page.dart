import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';

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
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed(RouteNames.search),
            tooltip: '搜索',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // 刷新数据
          // TODO: 实现实际的数据刷新逻辑
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTabletOrDesktop)
                ..._buildTabletLayout(context, theme)
              else
                ..._buildPhoneLayout(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// 手机布局
  List<Widget> _buildPhoneLayout(BuildContext context, ThemeData theme) {
    return [
      _buildWelcomeCard(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      Text('最近阅�?', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildRecentReading(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      Text('阅读统计', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildReadingStats(context),
      SizedBox(height: LayoutBreakpoints.getSpacing(context)),
      Text('为你推荐', style: theme.textTheme.titleLarge),
      SizedBox(height: LayoutBreakpoints.getSpacing(context) / 2),
      _buildRecommendations(context),
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
                _buildWelcomeCard(context),
                SizedBox(height: spacing),
                Text('最近阅�?', style: theme.textTheme.titleLarge),
                SizedBox(height: spacing / 2),
                _buildRecentReading(context),
              ],
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReadingStats(context),
                SizedBox(height: spacing),
                Text('为你推荐', style: theme.textTheme.titleLarge),
                SizedBox(height: spacing / 2),
                _buildRecommendations(context),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;

    if (hour < 6) {
      greeting = '夜深�?';
    } else if (hour < 12) {
      greeting = '早上�?';
    } else if (hour < 14) {
      greeting = '中午?';
    } else if (hour < 18) {
      greeting = '下午�?';
    } else {
      greeting = '晚上�?';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
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
                  child: Icon(
                    Icons.auto_stories,
                    color: theme.colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
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
              '阅读是心灵的旅行',
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
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.pushNamed(RouteNames.search),
                    icon: const Icon(Icons.explore),
                    label: const Text('发现好书'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReading(BuildContext context) {
    final theme = Theme.of(context);

    final recentBooks = [
      {'title': '三体', 'author': '刘慈�?', 'progress': 0.65, 'chapter': '�?45 �?'},
      {'title': '活着', 'author': '余华', 'progress': 0.30, 'chapter': '�?12 �?'},
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
                  '还没有开始阅�?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pushNamed(RouteNames.bookshelf),
                  child: const Text('去书�?'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: recentBooks
          .map(
            (book) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => context.pushNamed(RouteNames.bookshelf),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.book,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book['title'] as String,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
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
                            ),
                            const SizedBox(height: 8),
                            Text(
                              book['chapter'] as String,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: book['progress'] as double,
                                minHeight: 6,
                                backgroundColor:
                                    theme.colorScheme.outlineVariant,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
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
            _buildStatItem(
              context,
              '阅读天数',
              '12',
              Icons.calendar_today,
              theme.colorScheme.primary,
            ),
            _buildDivider(theme),
            _buildStatItem(
              context,
              '阅读时长',
              '8.5h',
              Icons.timer,
              theme.colorScheme.secondary,
            ),
            _buildDivider(theme),
            _buildStatItem(
              context,
              '已读书籍',
              '3',
              Icons.book_online,
              theme.colorScheme.tertiary,
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

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    final theme = Theme.of(context);

    final recommendations = [
      {'title': '百年孤独', 'author': '加西亚·马尔克�?'},
      {'title': '1984', 'author': '乔治·奥威�?'},
      {'title': '小王�?', 'author': '圣埃克苏佩里'},
    ];

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recommendations.length,
        separatorBuilder: (context, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final book = recommendations[index];
          return SizedBox(
            width: 160,
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
          );
        },
      ),
    );
  }
}
