import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/data/search_service.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/presentation/widgets/ui_components.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
              padding: pagePadding.copyWith(top: 16, bottom: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
        horizontal: isDesktop ? 24 : 20,
        vertical: isDesktop ? 16 : 12,
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
                  Icons.search_rounded,
                  color: theme.colorScheme.primary,
                ),
                suffixIcon: Watch.builder(
                  builder: (context) {
                    if (vm.keyword.value.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        vm.updateKeyword('');
                        vm.clear();
                      },
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
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 14 : 12,
                ),
              ),
              style: theme.textTheme.bodyLarge,
              onSubmitted: (value) {
                vm.updateKeyword(value);
                vm.search();
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              vm.updateKeyword(_searchController.text);
              vm.search();
            },
            icon: const Icon(Icons.search_rounded),
            label: Text(isDesktop ? '搜索' : ''),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 16,
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
                    const SizedBox(height: 16),
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
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text('搜索失败：${async.error}'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => vm.search(),
                      icon: const Icon(Icons.refresh_rounded),
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
                      Icons.search_off_rounded,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    const SizedBox(height: 24),
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
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 80,
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
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
                  padding: const EdgeInsets.all(24),
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
      margin: const EdgeInsets.only(bottom: 16),
      child: GradientCard(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
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
            SizedBox(width: isDesktop ? 20 : 16),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chrome_reader_mode_rounded,
                              size: 12,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 4),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              size: 12,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
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
                        Icons.arrow_forward_ios_rounded,
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
        Icons.book_rounded,
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
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 120,
                            height: 160,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.book_rounded, size: 48),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  label: '作者',
                  value: result.author,
                  icon: Icons.person_rounded,
                  theme: theme,
                ),
                _buildInfoRow(
                  label: '章节数',
                  value: '${result.totalChapters} 章',
                  icon: Icons.chrome_reader_mode_rounded,
                  theme: theme,
                ),
                _buildInfoRow(
                  label: '来源',
                  value: result.source,
                  icon: Icons.storage_rounded,
                  theme: theme,
                ),
                if (result.description != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '简介',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        const Icon(Icons.check_circle_rounded),
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
                        Icon(Icons.info_outline_rounded),
                        SizedBox(width: 12),
                        Text('添加失败，书籍可能已存在'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.bookmark_add_rounded),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
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
