    /// 书签管理页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api.dart';
import '../../../../di/service_locator.dart';

/// 书签管理页面
class BookmarkManagePage extends HookWidget {
  final int bookId;

  const BookmarkManagePage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    // final bookmarks = useSignal(vm.bookmarks.value);

    // 加载书签
    useEffect(() {
      vm.loadBookmarks();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书签管理'),
        actions: [
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
                  Text('加载失败{async.error}'),
                ],
              ),
            );
          }

          final bookmarkList = async.value ?? [];

          if (bookmarkList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无书签',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '阅读时点击顶部书签图标添',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .4),
                    ),
                  ),
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
              return _BookmarkTile(
                bookmark: bookmark,
                onTap: () => _jumpToBookmark(context, vm, bookmark),
                onDelete: () => _deleteBookmark(context, vm, bookmark),
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
        content: Text('确定要删${bookmark.note ?? '书签'}"吗？'),
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

      // removeBookmark(
      //   bookId: 'Book_${vm.bookId.value}',
      //   bookmarkId: bookmark.id,
      // );
      await vm.loadBookmarks();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('书签已删')));
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
      // 清空所有书签
      clearBookmarks(bookId: 'Book_${vm.bookId.value}');
      await vm.loadBookmarks();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('书签已清')));
      }
    }
  }
}

/// 书签列表
class _BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bookmark),
      title: Text(bookmark.note ?? '书签'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${bookmark.chapterId} '),
          if (bookmark.note != null && bookmark.note!.isNotEmpty)
            Text(
              bookmark.note!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDate(bookmark.createdAt),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            tooltip: '删除书签',
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}分钟';
      }
      return '${difference.inHours}小时';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}


