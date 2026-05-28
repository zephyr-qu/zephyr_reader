import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/article/application/article_view_model.dart';
import 'package:zephyr_reader/features/article/domain/models/article.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/presentation/widgets/states.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 文章列表页面
class ArticleListPage extends HookWidget {
  final ArticleViewModel vm;

  const ArticleListPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);

    // Load on mount
    useEffect(() {
      vm.load();
      return null;
    }, []);

    // Bind VM signal
    final articlesState = useSignalValue<AsyncState<List<Article>>, AsyncSignal<List<Article>>>(vm.articles);

    return Scaffold(
      body: CustomScrollView(
        physics: adaptiveScrollPhysics(context),
        slivers: [
          _buildAppBar(context, theme, deviceType),
          _buildArticleList(context, articlesState, theme, deviceType),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    return SliverAppBar(
      floating: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.go('/bookshelf'),
            child: Text(
              '书架',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing(Spacing.sm),
            ),
            child: Text(
              '/',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Text(
              '文章',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
          onPressed: () => context.pushNamed(RouteNames.search),
          tooltip: '搜索文章',
        ),
        SizedBox(
          width: deviceType == DeviceType.desktop
              ? DesignTokens.spacing(Spacing.md)
              : DesignTokens.spacing(Spacing.sm),
        ),
      ],
    );
  }

  Widget _buildArticleList(
    BuildContext context,
    AsyncState<List<Article>> articlesState,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    final pagePadding = LayoutBreakpoints.getPagePadding(context);

    // Loading 状态
    if (articlesState.isLoading) {
      return SliverPadding(
        padding: pagePadding,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return RepaintBoundary(
              child: _buildSkeletonCard(context, index),
            );
          }, childCount: 5),
        ),
      );
    }

    // Error 状态
    if (articlesState.hasError) {
      return SliverPadding(
        padding: pagePadding,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
              child: EmptyState(
                icon: PhosphorIconsRegular.warningCircle,
                title: '加载失败',
                subtitle: articlesState.error?.toString() ?? '未知错误',
                actionLabel: '重试',
                onAction: vm.load,
              ),
            ),
          ),
        ),
      );
    }

    final articles = articlesState.value ?? [];

    // Empty 状态
    if (articles.isEmpty) {
      return SliverPadding(
        padding: pagePadding,
        sliver: SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
              child: EmptyState(
                icon: PhosphorIconsRegular.fileText,
                title: '暂无文章',
                subtitle: '文章列表空空如也',
                actionLabel: '刷新',
                onAction: vm.load,
              ),
            ),
          ),
        ),
      );
    }

    // 文章列表
    return SliverPadding(
      padding: pagePadding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= articles.length) return const SizedBox.shrink();
          final article = articles[index];
          return RepaintBoundary(
            child: _buildArticleCard(context, article, theme, index)
                .animate()
                .fadeIn(delay: (100 * index).ms, duration: 400.ms)
                .slideY(begin: 0.05, end: 0),
          );
        }, childCount: articles.length),
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context, int index) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.spacing(Spacing.md)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(width: DesignTokens.spacing(Spacing.md)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.md)),
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 12,
                          width: 60,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (200 * index).ms).shimmer(duration: 1500.ms);
  }

  Widget _buildArticleCard(
    BuildContext context,
    Article article,
    ThemeData theme,
    int index,
  ) {
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.spacing(Spacing.md)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/articles/${article.id}'),
          child: Padding(
            padding: EdgeInsets.all(
              isDesktop ? 20 : DesignTokens.spacing(Spacing.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: isDesktop ? 140 : 100,
                    height: isDesktop ? 140 : 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: article.coverUrl != null
                        ? Image.network(
                            article.coverUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            cacheWidth: 120,
                            cacheHeight: 80,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildCoverPlaceholder(theme, isDesktop);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildCoverPlaceholder(theme, isDesktop),
                  ),
                ),
                SizedBox(width: DesignTokens.spacing(Spacing.md)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                      Text(
                        article.summary,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.spacing(Spacing.sm),
                              vertical: DesignTokens.spacing(Spacing.xs),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radius(RadiusSize.sm),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.user,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                                SizedBox(
                                  width: DesignTokens.spacing(Spacing.xs),
                                ),
                                Flexible(
                                  child: Text(
                                    article.author,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimaryContainer,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: DesignTokens.spacing(Spacing.sm)),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DesignTokens.spacing(Spacing.sm),
                              vertical: DesignTokens.spacing(Spacing.xs),
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(
                                DesignTokens.radius(RadiusSize.sm),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.clock,
                                  size: 12,
                                  color: theme.colorScheme.tertiary,
                                ),
                                SizedBox(
                                  width: DesignTokens.spacing(Spacing.xs),
                                ),
                                Text(
                                  '${article.readDuration}分钟',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            PhosphorIconsLight.caretRight,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme, bool isDesktop) {
    return Center(
      child: Icon(
        PhosphorIconsRegular.fileText,
        size: isDesktop ? 48 : 36,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }
}
