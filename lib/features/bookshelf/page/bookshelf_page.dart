import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

/// 书架页面 - 优化版
class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          _buildAppBar(context, theme, deviceType),
          // 分类筛选
          _buildCategoryFilter(context, vm, deviceType),
          // 书籍列表
          _buildBookList(context, vm, deviceType),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(RouteNames.search),
        icon: const Icon(Icons.add),
        label: const Text('添加书籍'),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    ThemeData theme,
    DeviceType deviceType,
  ) {
    return SliverAppBar(
      floating: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.book_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text('书架'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () => context.pushNamed(RouteNames.search),
          tooltip: '搜索',
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        IconButton(
          icon: const Icon(Icons.grid_view_rounded),
          onPressed: () {
            // 切换视图模式
          },
          tooltip: '视图',
        ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.pushNamed(RouteNames.settings),
          tooltip: '设置',
        ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
        SizedBox(width: deviceType == DeviceType.desktop ? 16 : 8),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    BookshelfViewModel vm,
    DeviceType deviceType,
  ) {
    final spacing = deviceType == DeviceType.desktop ? 24.0 : 16.0;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: spacing, vertical: 12),
        child: Watch.builder(
          builder: (context) {
            final categories = BookCategory.values;
            final selected = vm.selectedCategory.value;

            return SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == selected;

                  return IconChoiceChip(
                    label: category.displayName,
                    selected: isSelected,
                    onTap: () => vm.selectCategory(category),
                    selectedColor: Theme.of(context).colorScheme.primary,
                  ).animate().fadeIn(delay: (50 * index).ms, duration: 300.ms);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookList(
    BuildContext context,
    BookshelfViewModel vm,
    DeviceType deviceType,
  ) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Watch.builder(
          builder: (context) {
            try {
              final async = vm.books.value;

              // Loading 状态
              if (async.isLoading) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '加载中...',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Error 状态
              if (async.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(
                      deviceType == DeviceType.desktop ? 24 : 16,
                    ),
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: '加载失败',
                      subtitle: async.error.toString(),
                      actionLabel: '重试',
                      onAction: vm.loadBooks,
                    ),
                  ),
                );
              }

              final books = async.value ?? [];

              // Empty 状态
              if (books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(
                      deviceType == DeviceType.desktop ? 24 : 16,
                    ),
                    child: EmptyState(
                      icon: Icons.book_outlined,
                      title: '书架空空如也',
                      subtitle: '快去添加喜欢的书籍吧',
                      actionLabel: '去搜索',
                      onAction: () => context.pushNamed(RouteNames.search),
                    ),
                  ),
                );
              }

              // 书籍网格列表 - 使用 GridView 代替 SliverGrid
              return Padding(
                padding: EdgeInsets.all(
                  deviceType == DeviceType.desktop ? 24 : 16,
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: deviceType == DeviceType.phone ? 2 : 3,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: deviceType == DeviceType.phone ? 14 : 18,
                    mainAxisSpacing: deviceType == DeviceType.phone ? 14 : 18,
                  ),
                  itemCount: books.length,
                  itemBuilder: (context, index) {
                    if (index >= books.length) {
                      return const SizedBox.shrink();
                    }
                    final book = books[index];
                    return _buildBookCard(context, book, deviceType)
                        .animate()
                        .fadeIn(delay: (50 * index).ms, duration: 400.ms)
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutBack,
                        );
                  },
                ),
              );
            } catch (e, stackTrace) {
              // 捕获所有未预期的错误
              debugPrint('Bookshelf build error: $e');
              debugPrint('Stack trace: $stackTrace');
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(
                    deviceType == DeviceType.desktop ? 24 : 16,
                  ),
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: '发生错误',
                    subtitle: e.toString(),
                    actionLabel: '重试',
                    onAction: vm.loadBooks,
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    Book book,
    DeviceType deviceType,
  ) {
    final theme = Theme.of(context);
    final isDesktop = deviceType == DeviceType.desktop;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: isDesktop ? 4 : 2,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: InkWell(
        onTap: () => context.pushNamed(
          RouteNames.bookDetail,
          pathParameters: {'id': book.id.toString()},
        ),
        onLongPress: () {
          _showBookOptions(context, book);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.secondaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    book.coverPath != null
                        ? Image.network(
                            book.coverPath!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.book_rounded,
                                  size: isDesktop ? 56 : 48,
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              );
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
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Icon(
                              Icons.book_rounded,
                              size: isDesktop ? 56 : 48,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                    // 进度指示
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(book.progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 书籍信息
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatusChip(book.status, theme),
                      const Spacer(),
                      Text(
                        '${book.totalChapters}章',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // 阅读进度条
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: book.progress / 100,
                      minHeight: 3,
                      backgroundColor: theme.colorScheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    String label;

    switch (status) {
      case 'reading':
        color = Colors.blue;
        label = '阅读中';
        break;
      case 'completed':
        color = Colors.green;
        label = '已完结';
        break;
      case 'dropped':
        color = Colors.grey;
        label = '已弃坑';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showBookOptions(BuildContext context, Book book) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.book_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('继续阅读'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed(
                  RouteNames.reader,
                  pathParameters: {'id': book.id.toString()},
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: const Text('书籍详情'),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed(
                  RouteNames.bookDetail,
                  pathParameters: {'id': book.id.toString()},
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: const Text('编辑信息'),
              onTap: () {
                Navigator.pop(context);
                // 编辑书籍信息
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('删除书籍'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirm(context, book);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${book.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // 删除书籍
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已删除"${book.title}"')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
