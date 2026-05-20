import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/article/application/article_view_model.dart';
import 'package:zephyr_reader/features/article/domain/models/article.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';

/// 文章详情页面
class ArticleDetailPage extends StatefulWidget {
  final int articleId;

  const ArticleDetailPage({super.key, required this.articleId});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final ArticleViewModel _vm;
  late final ScrollController _scrollController;

  // 使用 ValueNotifier 代替 setState，避免不必要的重建
  final _scrollProgressNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _vm = getIt<ArticleViewModel>();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _vm.loadDetail(widget.articleId);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgressNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    try {
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;

      final maxScroll = position.maxScrollExtent;
      final currentScroll = position.pixels;
      // 使用 ValueNotifier 更新，避免 setState 导致的重建
      _scrollProgressNotifier.value = maxScroll > 0
          ? currentScroll / maxScroll
          : 0;
    } catch (e) {
      Logging.debug('Scroll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);

    return Scaffold(
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildAppBar(context, theme, deviceType)];
        },
        body: Watch.builder(
          builder: (context) {
            final async = _vm.selectedArticle.value;

            // Loading 状态
            if (async.isLoading) {
              return _buildDetailSkeleton(theme);
            }

            // Error 状态
            if (async.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(PhosphorIconsRegular.warningCircle, size: 64),
                      const SizedBox(height: 16),
                      Text('加载失败：${async.error}'),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _vm.loadDetail(widget.articleId),
                        icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final article = async.value;
            if (article == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(PhosphorIconsRegular.fileText, size: 64),
                    const SizedBox(height: 16),
                    Text('文章不存在', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go('/articles'),
                      icon: const Icon(PhosphorIconsRegular.arrowLeft),
                      label: const Text('返回文章列表'),
                    ),
                  ],
                ),
              );
            }

            return _buildArticleContent(context, article, theme, deviceType);
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: theme.colorScheme.surface,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 书架标题（可点击切换）
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
          // 斜线分隔符
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          // 文章标题（可点击切换）
          GestureDetector(
            onTap: () {
              // 当前已在文章页面，无需操作
            },
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
          icon: const Icon(PhosphorIconsRegular.shareNetwork),
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('分享功能开发中')));
          },
          tooltip: '分享',
        ),
        IconButton(
          icon: const Icon(PhosphorIconsRegular.bookmarkSimple),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(PhosphorIconsFill.checkCircle, color: Colors.white),
                    SizedBox(width: 12),
                    Text('已收藏'),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          tooltip: '收藏',
        ),
        SizedBox(width: deviceType == DeviceType.desktop ? 16 : 8),
      ],
    );
  }

  Widget _buildDetailSkeleton(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息骨架
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 标题骨架
          Container(
            height: 32,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          // 封面图骨架
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 24),
          // 内容骨架
          ...List.generate(
            8,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().shimmer(duration: 1500.ms);
  }

  Widget _buildArticleContent(
    BuildContext context,
    Article article,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    final pagePadding = LayoutBreakpoints.getPagePadding(context);
    final articleCoverCacheWidth =
        ((MediaQuery.of(context).size.width - 32) *
                MediaQuery.of(context).devicePixelRatio)
            .ceil();

    return SingleChildScrollView(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者信息卡片
          _buildAuthorCard(
            context,
            article,
            theme,
          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05, end: 0),

          const SizedBox(height: 24),

          // 文章标题
          Text(
            article.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

          const SizedBox(height: 16),

          // 文章元信息
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaChip(
                context,
                icon: PhosphorIconsRegular.calendarBlank,
                label: article.publishedAt,
              ),
              _buildMetaChip(
                context,
                icon: PhosphorIconsRegular.clock,
                label: '${article.readDuration} 分钟',
              ),
              _buildMetaChip(
                context,
                icon: PhosphorIconsRegular.textAa,
                label: '${article.wordCount} 字',
              ),
            ],
          ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

          const SizedBox(height: 32),

          // 文章封面图
          if (article.coverUrl != null)
            ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    article.coverUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: articleCoverCacheWidth,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildImagePlaceholder(theme);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),

          if (article.coverUrl != null) const SizedBox(height: 32),

          // 文章内容
          _buildArticleContentText(
            context,
            article,
            theme,
          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

          const SizedBox(height: 48),

          // 阅读进度指示器
          _buildProgressIndicator(context, theme),

          const SizedBox(height: 32),

          // 底部操作按钮
          _buildBottomActions(context, theme, article),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAuthorCard(
    BuildContext context,
    Article article,
    ThemeData theme,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  article.author[0].toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.author,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '作者',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsRegular.userCirclePlus),
              onPressed: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('关注功能开发中')));
              },
              tooltip: '关注作者',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Icon(
          PhosphorIconsRegular.image,
          size: 64,
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildArticleContentText(
    BuildContext context,
    Article article,
    ThemeData theme,
  ) {
    // 简单的 Markdown 渲染（可以后续使用 flutter_markdown 包增强）
    final content = article.content;

    return SelectableText(
      content,
      style: theme.textTheme.bodyLarge?.copyWith(
        height: 1.8,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '阅读进度',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            // 使用 ValueListenableBuilder 监听进度变化
            ValueListenableBuilder<double>(
              valueListenable: _scrollProgressNotifier,
              builder: (context, progress, _) {
                return Text(
                  '${(progress * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: ValueListenableBuilder<double>(
            valueListenable: _scrollProgressNotifier,
            builder: (context, progress, _) {
              return LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    ThemeData theme,
    Article article,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('点赞功能开发中')));
            },
            icon: const Icon(PhosphorIconsRegular.heart),
            label: const Text('点赞'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('评论功能开发中')));
            },
            icon: const Icon(PhosphorIconsRegular.chatCircle),
            label: const Text('评论'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        PhosphorIconsFill.checkCircle,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Text('已收藏"${article.title}"'),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(PhosphorIconsFill.bookmarkSimple),
            label: const Text('收藏'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
