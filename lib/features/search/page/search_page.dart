import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/application/services/full_text_search_service.dart';
import 'package:zephyr_reader/features/search/data/search_service.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/presentation/widgets/cards.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 搜索页面 - 响应式设计
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final vm = getIt<SearchViewModel>();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _historyService = SearchHistoryService();

  // 防止重复加载
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    try {
      // 检查是否可滚动
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;

      // 防止重复加载
      if (_isLoadingMore) return;
      if (!vm.hasMore.value) return;

      final threshold = position.maxScrollExtent - 200;
      if (position.pixels >= threshold) {
        _isLoadingMore = true;
        vm
            .loadMore()
            .then((_) {
              if (mounted) {
                _isLoadingMore = false;
              }
            })
            .catchError((_) {
              if (mounted) {
                _isLoadingMore = false;
              }
            });
      }
    } catch (e) {
      debugPrint('Scroll error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          _buildAppBar(context, theme, deviceType),
          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: pagePadding.copyWith(
                top: DesignTokens.spacing(Spacing.md),
                bottom: DesignTokens.spacing(Spacing.md),
              ),
              child: _buildSearchBar(context, theme),
            ).animate().fadeIn(duration: 400.ms),
          ),
          // 搜索结果
          _buildResults(context, theme, pagePadding),
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
            onTap: () => GoRouter.of(context).go('/bookshelf'),
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
            onTap: () => GoRouter.of(context).go('/articles'),
            child: Text(
              '文章',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.normal,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.push(RoutePaths.bookSearch),
          child: const Text('全文搜索', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? DesignTokens.spacing(Spacing.lg) : 20,
        vertical: isDesktop ? DesignTokens.spacing(Spacing.md) : 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索小说名称或作者',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                prefixIcon: Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  color: theme.colorScheme.primary,
                ),
                suffixIcon: Watch.builder(
                  builder: (context) {
                    if (vm.keyword.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(PhosphorIconsRegular.x),
                      onPressed: () {
                        _searchController.clear();
                        vm.updateKeyword('');
                        vm.clear();
                      },
                      tooltip: '清除',
                    );
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : DesignTokens.spacing(Spacing.md),
                  vertical: isDesktop ? 14 : 12,
                ),
              ),
              style: theme.textTheme.bodyLarge,
              onSubmitted: (value) {
                _historyService.addHistory(value);
                vm.updateKeyword(value);
                vm.search();
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              _historyService.addHistory(_searchController.text);
              vm.updateKeyword(_searchController.text);
              vm.search();
            },
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            label: Text(isDesktop ? '搜索' : ''),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop
                    ? DesignTokens.spacing(Spacing.lg)
                    : DesignTokens.spacing(Spacing.md),
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    ThemeData theme,
    EdgeInsets pagePadding,
  ) {
    return SliverPadding(
      padding: pagePadding,
      sliver: Watch.builder(
        builder: (context) {
          final async = vm.results.value;

          if (async.isLoading && vm.currentPage.value == 1) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: DesignTokens.spacing(Spacing.md)),
                    Text(
                      '搜索中...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (async.hasError) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.md)),
                    Text('搜索失败：${async.error}'),
                    SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                    FilledButton.icon(
                      onPressed: () => vm.search(),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          final results = async.value ?? [];

          if (results.isEmpty && vm.keyword.value.isNotEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.magnifyingGlassMinus,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                    Text(
                      '未找到 "${vm.keyword.value}" 相关的小说',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (results.isEmpty) {
            final history = _historyService.getHistory();
            if (history.isNotEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: DesignTokens.spacing(Spacing.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '搜索历史',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _historyService.clearHistory());
                            },
                            icon: Icon(
                              PhosphorIconsRegular.trash,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(
                              '清空',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                      Wrap(
                        spacing: DesignTokens.spacing(Spacing.sm),
                        runSpacing: DesignTokens.spacing(Spacing.sm),
                        children: history.map((query) {
                          return InputChip(
                            label: Text(
                              query,
                              style: const TextStyle(fontSize: 13),
                            ),
                            onPressed: () {
                              _searchController.text = query;
                              vm.updateKeyword(query);
                              vm.search();
                            },
                            onDeleted: () {
                              setState(
                                () => _historyService.removeHistory(query),
                              );
                            },
                            deleteIconColor: theme.colorScheme.onSurfaceVariant,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      PhosphorIconsRegular.book,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                    Text(
                      '输入关键词开始搜索',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // 使用 SliverList 实现列表布局
          final deviceType = LayoutBreakpoints.getDeviceType(context);

          return SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < results.length) {
                return _buildResultItem(results[index], theme, deviceType)
                    .animate()
                    .fadeIn(delay: (50 * index).ms, duration: 300.ms)
                    .slideY(begin: 0.05, end: 0);
              } else if (vm.hasMore.value) {
                return Padding(
                  padding: EdgeInsets.all(DesignTokens.spacing(Spacing.lg)),
                  child: Watch.builder(
                    builder: (context) {
                      return vm.isSearching.value
                          ? const Center(child: CircularProgressIndicator())
                          : const Center(child: Text('没有更多了'));
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }, childCount: results.length + (vm.hasMore.value ? 1 : 0)),
          );
        },
      ),
    );
  }

  Widget _buildResultItem(
    SearchResult result,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    final isDesktop = deviceType == DeviceType.desktop;

    return Container(
      margin: EdgeInsets.only(bottom: DesignTokens.spacing(Spacing.md)),
      child: GradientCard(
        padding: EdgeInsets.all(
          isDesktop ? 20 : DesignTokens.spacing(Spacing.md),
        ),
        onTap: () => _showPreview(result),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面图
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: isDesktop ? 80 : 60,
                height: isDesktop ? 120 : 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: result.coverUrl != null
                    ? Image.network(
                        result.coverUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        cacheWidth: 60,
                        cacheHeight: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildCoverPlaceholder(theme, isDesktop);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
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
            SizedBox(width: isDesktop ? 20 : DesignTokens.spacing(Spacing.md)),
            // 书籍信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.sm)),
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
                            SizedBox(width: DesignTokens.spacing(Spacing.xs)),
                            Text(
                              result.author,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              PhosphorIconsRegular.bookOpen,
                              size: 12,
                              color: theme.colorScheme.tertiary,
                            ),
                            SizedBox(width: DesignTokens.spacing(Spacing.xs)),
                            Text(
                              '${result.totalChapters}章',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (result.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      result.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      maxLines: isDesktop ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: DesignTokens.spacing(Spacing.sm),
                          vertical: DesignTokens.spacing(Spacing.xs),
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radius(RadiusSize.sm),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsRegular.hardDrives,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                            SizedBox(width: DesignTokens.spacing(Spacing.xs)),
                            Text(
                              result.source,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        PhosphorIconsLight.caretRight,
                        size: 16,
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
    );
  }

  Widget _buildCoverPlaceholder(ThemeData theme, bool isDesktop) {
    return Center(
      child: Icon(
        PhosphorIconsRegular.book,
        size: isDesktop ? 40 : 28,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }

  void _showPreview(SearchResult result) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isDesktop = deviceType == DeviceType.desktop;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.title),
        content: SizedBox(
          width: isDesktop ? 500 : null,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (result.coverUrl != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        result.coverUrl!,
                        width: 120,
                        height: 160,
                        cacheWidth: 60,
                        cacheHeight: 80,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 160,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              PhosphorIconsRegular.book,
                              size: 48,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                _buildInfoRow(
                  label: '作者',
                  value: result.author,
                  icon: PhosphorIconsRegular.user,
                  theme: theme,
                ),
                _buildInfoRow(
                  label: '章节数',
                  value: '${result.totalChapters} 章',
                  icon: PhosphorIconsRegular.bookOpen,
                  theme: theme,
                ),
                _buildInfoRow(
                  label: '来源',
                  value: result.source,
                  icon: PhosphorIconsRegular.hardDrives,
                  theme: theme,
                ),
                if (result.description != null) ...[
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    '简介',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                  Text(
                    result.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);

              // 添加到书架
              final repo = GetIt.I.get<BookRepository>();
              final book = await repo.createBook(
                title: result.title,
                author: result.author,
                filePath: result.id,
                fileFormat: 'web',
                totalChapters: result.totalChapters,
                description: result.description,
                coverPath: result.coverUrl,
              );

              if (!context.mounted) return;

              if (book != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(PhosphorIconsFill.checkCircle),
                        const SizedBox(width: 12),
                        Text('已添加 ${result.title} 到书架'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(PhosphorIconsRegular.info),
                        SizedBox(width: 12),
                        Text('添加失败，书籍可能已存在'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(PhosphorIconsRegular.bookmarkSimple),
            label: const Text('添加到书架'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(DesignTokens.spacing(Spacing.sm)),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.md),
              ),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
