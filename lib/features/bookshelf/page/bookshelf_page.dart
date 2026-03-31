import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/book_import_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/bookshelf_service.dart';
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
        onPressed: () => context.pushNamed(RouteNames.search),
        icon: const Icon(Icons.add),
        label: const Text('添加书籍'),
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

  void _showImportDialog(BuildContext context) {
    showDialog<Book>(
      context: context,
      builder: (context) => const _ImportDialog(),
    ).then((book) {
      if (book != null) {
        // 导入成功后刷新书架
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功添加"${book.title}"到书架'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
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
                  );
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
                        '${book.totalChapters} 章',
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

/// 导入书籍对话框
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _importService = GetIt.I.get<BookImportService>();
  final _bookshelfService = GetIt.I.get<BookshelfService>();

  String? _selectedFilePath;
  String? _bookTitle;
  String? _bookAuthor;
  int _chapterCount = 0;
  String? _coverPath;
  bool _isParsing = false;
  String? _parseError;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.upload_file_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '导入书籍',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '支持 TXT、EPUB、PDF 格式',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 文件选择区域
              _buildFileSelector(theme),

              if (_selectedFilePath != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // 书籍信息预览
                if (_bookTitle != null)
                  _buildInfoRow('书名', _bookTitle!, theme),
                if (_bookAuthor != null)
                  _buildInfoRow('作者', _bookAuthor!, theme),
                if (_chapterCount > 0)
                  _buildInfoRow('章节数', '$_chapterCount 章', theme),

                const SizedBox(height: 24),
              ],

              // 错误信息
              if (_parseError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _parseError!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: (_selectedFilePath != null &&
                              !_isParsing &&
                              !_isImporting)
                          ? _handleImport
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isImporting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('导入到书架'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileSelector(ThemeData theme) {
    return InkWell(
      onTap: _isParsing ? null : _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFilePath != null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: 2,
            style: _selectedFilePath != null
                ? BorderStyle.solid
                : BorderStyle.none,
          ),
          color: _selectedFilePath != null
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFilePath != null
                  ? Icons.check_circle
                  : Icons.upload_file,
              size: 48,
              color: _selectedFilePath != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilePath != null ? '已选择文件' : '点击选择书籍文件',
              style: theme.textTheme.titleMedium?.copyWith(
                color: _selectedFilePath != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                _selectedFilePath!.split('/').last,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() {
      _isParsing = true;
      _parseError = null;
    });

    try {
      final result = await _importService.selectFiles(
        allowMultiple: false,
        allowedExtensions: ['txt', 'epub', 'pdf'],
      );

      if (result == null || result.isEmpty) {
        setState(() {
          _isParsing = false;
        });
        return;
      }

      final file = result.first;
      final filePath = file.path;
      if (filePath == null) {
        setState(() {
          _isParsing = false;
          _parseError = '无法获取文件路径';
        });
        return;
      }

      // 导入文件并解析
      final task = await _importService.importFile(file);

      if (task.status != ImportTaskStatus.completed) {
        setState(() {
          _isParsing = false;
          _parseError = task.error ?? '解析失败';
        });
        return;
      }

      setState(() {
        _selectedFilePath = task.filePath;
        _bookTitle = task.title;
        _bookAuthor = task.author;
        _chapterCount = task.chapterCount ?? 0;
        _coverPath = task.coverPath;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _parseError = '解析失败：$e';
      });
    }
  }

  Future<void> _handleImport() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      // 创建临时 ImportTask 用于导入
      final task = ImportTask(
        filePath: _selectedFilePath!,
        fileName: _selectedFilePath!.split('/').last,
        format: _selectedFilePath!.split('.').last,
        fileSize: 0,
        bookId: 0,
        title: _bookTitle,
        author: _bookAuthor,
        chapterCount: _chapterCount,
        coverPath: _coverPath,
      );

      // 添加到书架
      final book = await _bookshelfService.addBookFromImportTask(task);

      if (book != null && mounted) {
        Navigator.pop(context, book);
      } else {
        setState(() {
          _isImporting = false;
          _parseError = '导入失败';
        });
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _parseError = '导入失败：$e';
      });
    }
  }
}
