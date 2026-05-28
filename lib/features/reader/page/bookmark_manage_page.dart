library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/data/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import '../../../../di/service_locator.dart';

enum BookmarkSortType { createdAt, chapterIndex, position }

class BookmarkManagePage extends HookWidget {
  final String bookId;
  const BookmarkManagePage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    final searchController = useTextEditingController();
    final isSearchMode = useSignal(false);
    final selectedBookmarks = useSignal<Set<String>>({});
    final sortBy = useSignal<BookmarkSortType>(BookmarkSortType.createdAt);
    final ascending = useSignal(false);
    final bookmarkStats = useSignal<int?>(null);

    useEffect(() {
      vm.loadBookmarks();
      () async {
        final list = await bookmark_api.listBookmarksByBook(bookId: bookId);
        bookmarkStats.value = list.length;
      }();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: isSearchMode.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索书签...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (_) => vm.loadBookmarks(),
              )
            : const Text('书签管理'),
        actions: [
          if (!isSearchMode.value)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              onPressed: () => isSearchMode.value = true,
              tooltip: '搜索',
            )
          else
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: () {
                isSearchMode.value = false;
                searchController.clear();
                vm.loadBookmarks();
              },
              tooltip: '关闭搜索',
            ),
          PopupMenuButton<BookmarkSortType>(
            icon: const Icon(PhosphorIconsRegular.sortAscending),
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
                value: BookmarkSortType.chapterIndex,
                child: Text('按章节排序'),
              ),
              const PopupMenuItem(
                value: BookmarkSortType.position,
                child: Text('按位置排序'),
              ),
            ],
          ),
          if (selectedBookmarks.value.isNotEmpty)
            IconButton(
              icon: Badge(
                label: Text('${selectedBookmarks.value.length}'),
                child: const Icon(PhosphorIconsRegular.trash),
              ),
              onPressed: () =>
                  _batchDelete(context, vm, selectedBookmarks.value),
              tooltip: '删除选中',
            )
          else
            IconButton(
              icon: const Icon(PhosphorIconsRegular.trashSimple),
              onPressed: () => _confirmClearBookmarks(context, vm),
              tooltip: '清空所有',
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
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    '加载失败',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  FilledButton.icon(
                    onPressed: () => vm.loadBookmarks(),
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
                    label: const Text('重新加载'),
                  ),
                ],
              ),
            );
          }

          var bookmarkList = (async.value ?? []).whereType<Bookmark>().toList();

          if (isSearchMode.value && searchController.text.isNotEmpty) {
            final keyword = searchController.text.toLowerCase();
            bookmarkList = bookmarkList
                .where(
                  (b) =>
                      b.title.toLowerCase().contains(keyword) ||
                      b.chapterIndex.toString().contains(keyword),
                )
                .toList();
          }

          bookmarkList.sort((a, b) {
            int result;
            switch (sortBy.value) {
              case BookmarkSortType.createdAt:
                result = a.createdAt.compareTo(b.createdAt);
              case BookmarkSortType.chapterIndex:
                result = a.chapterIndex.compareTo(b.chapterIndex);
              case BookmarkSortType.position:
                result = a.charOffset.compareTo(b.charOffset);
            }
            return ascending.value ? result : -result;
          });

          if (bookmarkList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.bookmarkSimple,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    isSearchMode.value ? '未找到相关书签' : '暂无书签',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (!isSearchMode.value) ...[
                    SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                    Text(
                      '阅读时点击右上角添加书签',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return Column(
            children: [
              if (bookmarkStats.value != null)
                Container(
                  margin: EdgeInsets.fromLTRB(
                    20,
                    DesignTokens.spacing(Spacing.sm),
                    20,
                    DesignTokens.spacing(Spacing.xs),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: DesignTokens.spacing(Spacing.sm),
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radius(RadiusSize.md),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.bookmarkSimple,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: DesignTokens.spacing(Spacing.sm)),
                      Text(
                        '共 ${bookmarkList.length} 个书签',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '本书总计 ${bookmarkStats.value} 个',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: bookmarkList.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 0.5, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    final bookmark = bookmarkList[index];
                    final isSelected = selectedBookmarks.value.contains(
                      bookmark.id,
                    );
                    return _BookmarkTile(
                      bookmark: bookmark,
                      isSelected: isSelected,
                      onTap: () {
                        vm.jumpToBookmark(bookmark);
                        context.pop();
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('删除书签'),
                            content: Text('确定要删除"${bookmark.title}"吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await vm.deleteBookmark(bookmark.id);
                        }
                      },
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _batchDelete(
    BuildContext context,
    ReaderViewModel vm,
    Set<String> bookmarkIds,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${bookmarkIds.length} 个书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      var successCount = 0;
      for (final id in bookmarkIds) {
        if (await vm.deleteBookmark(id)) successCount++;
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
      builder: (c) => AlertDialog(
        title: const Text('清空书签'),
        content: const Text('确定要清空本书的所有书签吗？此操作不可恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final bookmarks = vm.bookmarks.value.value ?? [];
      var successCount = 0;
      for (final b in bookmarks) {
        if (await vm.deleteBookmark(b.id)) successCount++;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已清空 $successCount 个书签')));
      }
    }
  }
}

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
      key: Key(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.primary,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: DesignTokens.spacing(Spacing.md)),
        child: const Icon(
          PhosphorIconsRegular.trash,
          color: Colors.white,
          size: 20,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('删除书签'),
                content: const Text('确定要删除此书签吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggleSelect,
              child: Padding(
                padding: const EdgeInsets.only(right: 10, top: 2),
                child: Icon(
                  isSelected
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.bookmarkSimple,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookmark.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                    Text(
                      '第 ${bookmark.chapterIndex} 章',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: DesignTokens.spacing(Spacing.sm)),
            Text(
              _formatDate(bookmark.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours == 0) return '${diff.inMinutes}分钟前';
    if (diff.inDays == 0) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
