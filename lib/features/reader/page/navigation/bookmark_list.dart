class BookmarkList extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final String bookId;
  final Color textColor, dimColor, accentColor;
  final ValueChanged<Bookmark> onBookmarkSelected;
  final VoidCallback? onAddBookmark;
  final ValueChanged<String> onDeleteBookmark;

  const BookmarkList({
    required this.bookmarks,
    required this.bookId,
    required this.textColor,
    required this.dimColor,
    required this.accentColor,
    required this.onBookmarkSelected,
    this.onAddBookmark,
    required this.onDeleteBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.bookmarkSimple,
              size: 48,
              color: dimColor,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noBookmarks,
              style: TextStyle(fontSize: 15, color: dimColor),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addBookmarkHint,
              style: theme.textTheme.labelLarge?.copyWith(color: dimColor),
            ),
            const SizedBox(height: 16),
            if (onAddBookmark != null)
              FilledButton.tonalIcon(
                icon: const Icon(PhosphorIconsRegular.plusCircle, size: 18),
                label: Text(l10n.addBookmark),
                onPressed: onAddBookmark,
              ),
          ],
        ),
      );
    }

    final sorted = List<Bookmark>.from(bookmarks)
      ..sort((a, b) => a.charOffset.compareTo(b.charOffset));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.totalBookmarks(bookmarks.length),
                  style: theme.textTheme.labelLarge?.copyWith(color: dimColor),
                ),
              ),
              TextButton.icon(
                icon: Icon(
                  PhosphorIconsRegular.addressBook,
                  size: 16,
                  color: accentColor,
                ),
                label: Text(
                  l10n.bookmarkManage,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accentColor,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed(
                    RouteNames.bookmarkManage,
                    pathParameters: {'bookId': bookId},
                  );
                },
              ),
              if (onAddBookmark != null)
                IconButton(
                  icon: Icon(
                    PhosphorIconsRegular.plusCircle,
                    color: accentColor,
                    size: 20,
                  ),
                  onPressed: onAddBookmark,
                  tooltip: l10n.addBookmark,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: sorted.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 16,
              color: dimColor.withValues(alpha: 0.15),
            ),
            itemBuilder: (_, i) {
              final bm = sorted[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: Icon(
                  PhosphorIconsRegular.bookmarkSimple,
                  color: accentColor,
                  size: 20,
                ),
                title: Text(
                  bm.title.isNotEmpty ? bm.title : l10n.unknownBook,
                  style: TextStyle(fontSize: 14, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Ch.${bm.chapterIndex + 1} @ ${bm.charOffset}',
                  style: TextStyle(fontSize: 12, color: dimColor),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.arrowUpRight,
                        size: 18,
                        color: dimColor,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onBookmarkSelected(bm);
                      },
                      tooltip: l10n.jumpTo,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.trash,
                        size: 16,
                        color: dimColor,
                      ),
                      onPressed: () => _confirmDelete(context, bm, l10n),
                      tooltip: l10n.delete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onBookmarkSelected(bm);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext ctx, Bookmark bm, AppLocalizations l10n) {
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(l10n.deleteBookmark),
        content: Text(
          bm.title.isNotEmpty
              ? l10n.confirmDeleteBookmark(bm.title)
              : l10n.confirmDeleteBookmarkSimple,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              onDeleteBookmark(bm.id);
              Navigator.of(c).pop();
            },
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
