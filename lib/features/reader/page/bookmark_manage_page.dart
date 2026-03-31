/// 书签管理页面 - 完善版
///
/// 提供完整的书签管理功能：
/// - 书签列表展示
/// - 书签跳转
/// - 书签删除
/// - 批量操作
/// - 书签排序
/// - 书签搜索
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import '../../../../di/service_locator.dart';

/// 书签管理页面
class BookmarkManagePage extends HookWidget {
  final int bookId;

  const BookmarkManagePage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    final searchController = useTextEditingController();
    final isSearchMode = useSignal(false);
    final selectedBookmarks = useSignal<Set<int>>({});
    final sortBy = useSignal<BookmarkSortType>(BookmarkSortType.createdAt);
    final ascending = useSignal(false);

    // 加载书签
    useEffect(() {
      vm.loadBookmarks();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: isSearchMode.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书签...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => vm.loadBookmarks(),
              )
            : const Text('书签管理'),
        actions: [
          // 搜索按钮
          if (!isSearchMode.value)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => isSearchMode.value = true,
              tooltip: '搜索书签',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                isSearchMode.value = false;
                searchController.clear();
                vm.loadBookmarks();
              },
              tooltip: '关闭搜索',
            ),
          // 排序按钮
          PopupMenuButton<BookmarkSortType>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (type) {
              sortBy.value = type;
              ascending.value = !ascending.value;
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: BookmarkSortType.createdAt,
                child: Text('按时间排序'),
              ),
              const PopupMenuItem(
                value: BookmarkSortType.chapterId,
                child: Text('按章节排序'),
              ),
              const PopupMenuItem(
                value: BookmarkSortType.position,
                child: Text('按位置排序'),
              ),
            ],
          ),
          // 批量操作
          if (selectedBookmarks.value.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${selectedBookmarks.value.length}'),
                child: const Icon(Icons.delete_outline),
              ),
              onPressed: () => _batchDelete(context, vm, selectedBookmarks.value),
              tooltip: '批量删除',
            )
          else
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _confirmClearBookmarks(context, vm),
              tooltip: '清空书签',
            ),
        ],
      ),
      body: Watch.builder(
        builder: (context) {
          final async = vm.bookmarks.value;

          if (async.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (async.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('加载失败：${async.error}'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => vm.loadBookmarks(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新加载'),
                  ),
                ],
              ),
            );
          }

          var bookmarkList = async.value ?? [];

          // 搜索过滤
          if (isSearchMode.value && searchController.text.isNotEmpty) {
            final keyword = searchController.text.toLowerCase();
            bookmarkList = bookmarkList.where((b) {
              return (b.note ?? '').toLowerCase().contains(keyword) ||
                  b.chapterId.toString().contains(keyword);
            }).toList();
          }

          // 排序
          bookmarkList.sort((a, b) {
            int result;
            switch (sortBy.value) {
              case BookmarkSortType.createdAt:
                result = a.createdAt.compareTo(b.createdAt);
                break;
              case BookmarkSortType.chapterId:
                result = a.chapterId.compareTo(b.chapterId);
                break;
              case BookmarkSortType.position:
                result = a.position.compareTo(b.position);
                break;
            }
            return ascending.value ? result : -result;
          });

          if (bookmarkList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isSearchMode.value ? '未找到相关书签' : '暂无书签',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSearchMode.value
                        ? '尝试其他搜索关键词'
                        : '阅读时点击书签图标添加书签',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  if (!isSearchMode.value) ...[
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => context.goNamed(RouteNames.home),
                      icon: const Icon(Icons.menu_book),
                      label: const Text('去读书'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: bookmarkList.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final bookmark = bookmarkList[index];
              final isSelected = selectedBookmarks.value.contains(bookmark.id);
              return _BookmarkTile(
                bookmark: bookmark,
                isSelected: isSelected,
                onTap: () => _jumpToBookmark(context, vm, bookmark),
                onDelete: () => _deleteBookmark(context, vm, bookmark),
                onLongPress: () {
                  selectedBookmarks.value = {
                    ...selectedBookmarks.value,
                    bookmark.id,
                  };
                },
                onToggleSelect: () {
                  if (isSelected) {
                    selectedBookmarks.value = selectedBookmarks.value
                        .where((id) => id != bookmark.id)
                        .toSet();
                  } else {
                    selectedBookmarks.value = {
                      ...selectedBookmarks.value,
                      bookmark.id,
                    };
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _jumpToBookmark(
    BuildContext context,
    ReaderViewModel vm,
    Bookmark bookmark,
  ) {
    vm.jumpToBookmark(bookmark);
    Navigator.pop(context);
  }

  Future<void> _deleteBookmark(
    BuildContext context,
    ReaderViewModel vm,
    Bookmark bookmark,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书签'),
        content: Text('确定要删除"${bookmark.note ?? '书签'}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await vm.deleteBookmark(bookmark.id);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('书签已删除')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败')),
          );
        }
      }
    }
  }

  Future<void> _batchDelete(
    BuildContext context,
    ReaderViewModel vm,
    Set<int> bookmarkIds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${bookmarkIds.length} 个书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      var successCount = 0;
      for (final id in bookmarkIds) {
        final success = await vm.deleteBookmark(id);
        if (success) successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 $successCount/${bookmarkIds.length} 个书签'),
          ),
        );
      }
    }
  }

  Future<void> _confirmClearBookmarks(
    BuildContext context,
    ReaderViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空书签'),
        content: const Text('确定要清空本书的所有书签吗？此操作不可恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 批量删除所有书签
      final bookmarks = vm.bookmarks.value.value ?? [];
      var successCount = 0;
      for (final bookmark in bookmarks) {
        final success = await vm.deleteBookmark(bookmark.id);
        if (success) successCount++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已清空 $successCount 个书签'),
          ),
        );
      }
    }
  }
}

/// 书签排序类型
enum BookmarkSortType {
  createdAt('时间'),
  chapterId('章节'),
  position('位置');

  final String label;
  const BookmarkSortType(this.label);
}

/// 书签列表项
class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onLongPress;
  final VoidCallback onToggleSelect;

  const _BookmarkTile({
    required this.bookmark,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onLongPress,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dismissible(
      key: Key(bookmark.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除书签'),
            content: const Text('确定要删除此书签吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: ListTile(
          leading: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                )
              : Icon(
                  Icons.bookmark,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
          title: Text(
            bookmark.note ?? '书签',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '第${bookmark.chapterId}章',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (bookmark.note != null && bookmark.note!.isNotEmpty)
                Text(
                  bookmark.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(bookmark.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '位置：${bookmark.position}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          onTap: onToggleSelect,
          onLongPress: onLongPress,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours == 0) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays == 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}
