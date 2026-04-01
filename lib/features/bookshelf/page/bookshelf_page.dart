import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/book_import_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/import_task.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

/// 书架页面 - 现代化设计
class BookshelfPage extends StatelessWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
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
        onPressed: () => _showImportDialog(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('导入书籍'),
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
        mainAxisAlignment: .center,
        children: [
          // Container(
          //   padding: const EdgeInsets.all(8),
          //   decoration: BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [
          //         theme.colorScheme.primary,
          //         theme.colorScheme.secondary,
          //         theme.colorScheme.tertiary,
          //       ],
          //       begin: Alignment.topLeft,
          //       end: Alignment.bottomRight,
          //     ),
          //     borderRadius: BorderRadius.circular(10),
          //     boxShadow: [
          //       BoxShadow(
          //         color: theme.colorScheme.primary.withValues(alpha: 0.3),
          //         blurRadius: 8,
          //         offset: const Offset(0, 2),
          //       ),
          //     ],
          //   ),
          //   child: const Icon(
          //     Icons.book_rounded,
          //     color: Colors.white,
          //     size: 20,
          //   ),
          // ),
          // const SizedBox(width: 12),
          Text(
            '书架',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: () => _showImportDialog(context),
          tooltip: '导入',
        ),
        IconButton(
          icon: const Icon(Icons.grid_view_rounded),
          onPressed: () {
            // 切换视图模式
          },
          tooltip: '视图',
        ),
        SizedBox(width: deviceType == DeviceType.desktop ? 16 : 8),
      ],
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final importService = getIt<BookImportService>();
    final bookshelfService = getIt<BookshelfService>();

    // 直接打开文件选择器
    final files = await importService.selectFiles(
      allowMultiple: false,
      allowedExtensions: ['txt', 'epub', 'pdf'],
    );

    if (files == null || files.isEmpty || !context.mounted) return;

    final file = files.first;
    final filePath = file.path;
    if (filePath == null) return;

    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('正在导入"${file.name}"...'),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );

    try {
      // 导入文件并解析
      final task = await importService.importFile(file);

      if (task.status != ImportTaskStatus.completed) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败：${task.error ?? '未知错误'}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }

      // 添加到书架
      final book = await bookshelfService.addBookFromImportTask(task);

      if (book != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功添加"${book.title}"到书架'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: '开始阅读',
              onPressed: () {
                context.pushNamed(
                  RouteNames.reader,
                  pathParameters: {'id': book.id.toString()},
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败：$e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Widget _buildCategoryFilter(
    BuildContext context,
    BookshelfViewModel vm,
    DeviceType deviceType,
  ) {
    final spacing = deviceType == DeviceType.desktop ? 24.0 : 16.0;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: spacing, vertical: 16),
        child: Watch.builder(
          builder: (context) {
            final categories = BookCategory.values;
            final selected = vm.selectedCategory.value;

            return SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == selected;

                  return _buildCategoryChip(
                    context,
                    category.displayName,
                    isSelected,
                    () => vm.selectCategory(category),
                    index,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap,
    int index,
  ) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 12,
                color: Colors.white,
              ),
            if (isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
                      subtitle: async.error?.toString() ?? '未知错误',
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
                    return _buildBookCard(context, book, deviceType);
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
      elevation: isDesktop ? 6 : 3,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              return _buildPlaceholder(theme, isDesktop);
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
                        : _buildPlaceholder(theme, isDesktop),
                    // 渐变遮罩
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    // 进度指示
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(book.progress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
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
              padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 6),
                  Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatusChip(book.status, theme),
                      const Spacer(),
                      Text(
                        '${book.totalChapters} 章',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // 阅读进度条
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: book.progress / 100,
                      minHeight: 4,
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

  Widget _buildPlaceholder(ThemeData theme, bool isDesktop) {
    return Center(
      child: Icon(
        Icons.book_rounded,
        size: isDesktop ? 56 : 48,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
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
