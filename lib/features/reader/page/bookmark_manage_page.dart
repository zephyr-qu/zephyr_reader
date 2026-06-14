import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/time_formatters.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/data/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../../di/service_locator.dart';

/// 书签排序类型。
enum BookmarkSortType { createdAt, chapterIndex, position }

class BookmarkManagePage extends HookWidget {
  final String bookId;
  const BookmarkManagePage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    final searchController = useTextEditingController();
    final isSearchMode = useSignal(false);
    final selectedBookmarks = useSetSignal<String>({});
    final sortBy = useSignal<BookmarkSortType>(BookmarkSortType.createdAt);
    final ascending = useSignal(false);

    useEffect(() {
      vm.bookmarks.loadBookmarks();
      return null;
    }, []);

    final AsyncState<List<Bookmark>> bookmarksState = useSignalValue(
      vm.bookmarks.bookmarks,
    );

    return Scaffold(
      appBar: AppBar(
        title: isSearchMode.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchBookmarkHint,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (_) {},
              )
            : Text(l10n.bookmarkManage),
        actions: [
          if (!isSearchMode.value)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              onPressed: () => isSearchMode.value = true,
              tooltip: l10n.search,
            )
          else
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: () {
                isSearchMode.value = false;
                searchController.clear();
                vm.bookmarks.loadBookmarks();
              },
              tooltip: l10n.closeSearch,
            ),
          PopupMenuButton<BookmarkSortType>(
            icon: const Icon(PhosphorIconsRegular.sortAscending),
            onSelected: (type) {
              sortBy.value = type;
              ascending.value = !ascending.value;
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: BookmarkSortType.createdAt,
                child: Text(l10n.sortByTime),
              ),
              PopupMenuItem(
                value: BookmarkSortType.chapterIndex,
                child: Text(l10n.sortByChapter),
              ),
              PopupMenuItem(
                value: BookmarkSortType.position,
                child: Text(l10n.sortByPosition),
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
              tooltip: l10n.deleteSelected,
            )
          else
            IconButton(
              icon: const Icon(PhosphorIconsRegular.trashSimple),
              onPressed: () => _confirmClearBookmarks(context, vm),
              tooltip: l10n.clearAll,
            ),
        ],
      ),
      body: () {
        final async = bookmarksState;
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
                  l10n.loadFailed,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                FilledButton.icon(
                  onPressed: () => vm.bookmarks.loadBookmarks(),
                  label: Text(l10n.reload),
                ),
              ],
            ),
          );
        }

        var bookmarkList = (async.value ?? <Bookmark>[]).toList();

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
                  isSearchMode.value ? l10n.noBookmarksFound : l10n.noBookmarks,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (!isSearchMode.value) ...[
                  SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                  Text(
                    l10n.addBookmarkHint,
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
            if (bookmarksState.value != null)
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
                      l10n.totalBookmarks(bookmarkList.length),
                      style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface),
                    ),
                    const Spacer(),
                    Text(
                      l10n.bookTotalBookmarks(
                        bookmarksState.value?.length ?? 0,
                      ),
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
                padding: EdgeInsets.symmetric(horizontal: DesignTokens.spacing(Spacing.md)),
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
                      vm.chapterManager.jumpToPosition(bookmark.chapterIndex, bookmark.charOffset.toInt());
                      context.pop();
                    },
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(l10n.deleteBookmark),
                          content: Text(
                            l10n.confirmDeleteBookmark(bookmark.title),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(l10n.delete),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await vm.bookmarks.deleteBookmark(bookmark.id);
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
      }(),
    );
  }

  Future<void> _batchDelete(
    BuildContext context,
    ReaderViewModel vm,
    Set<String> bookmarkIds,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.batchDelete),
        content: Text(l10n.confirmBatchDelete(bookmarkIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await bookmark_api.deleteBookmarks(bookmarkIds: bookmarkIds.toList());
      await vm.bookmarks.loadBookmarks();
      if (context.mounted) {
        showInfoSnack(context, l10n.deletedBookmarks(bookmarkIds.length));
      }
    }
  }

  Future<void> _confirmClearBookmarks(
    BuildContext context,
    ReaderViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.clearAllBookmarks),
        content: Text(l10n.confirmClearAllBookmarks),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l10n.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await bookmark_api.clearBookmarksByBook(bookId: bookId);
      await vm.bookmarks.loadBookmarks();
      if (context.mounted) {
        showInfoSnack(context, l10n.clearedAllBookmarks);
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
    final l10n = AppLocalizations.of(context)!;
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
                title: Text(l10n.deleteBookmark),
                content: Text(l10n.confirmDeleteBookmarkSimple),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(l10n.delete),
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
                      l10n.chapterN(bookmark.chapterIndex),
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
              formatRelativeTime(bookmark.createdAt, l10n),
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
}
