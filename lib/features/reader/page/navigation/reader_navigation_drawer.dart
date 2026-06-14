import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'chapter_list_widget.dart';

/// 阅读器导航侧边栏 — 目录/书签 双 TabBar。
class ReaderNavigationDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;

  final List<Bookmark> bookmarks;
  final ValueChanged<Bookmark> onBookmarkSelected;
  final VoidCallback? onAddBookmark;
  final ValueChanged<String> onDeleteBookmark;
  final ThemeMode themeMode;
  final String bookId;

  const ReaderNavigationDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.bookmarks,
    required this.onBookmarkSelected,
    this.onAddBookmark,
    required this.onDeleteBookmark,
    required this.themeMode,
    required this.bookId,
  });

  Color _dimColor(Color c) => c.withValues(alpha: 0.55);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final readerTheme = theme.extension<ReaderThemeExtension>()!;
    final tc = readerTheme.textColor;
    final dim = _dimColor(tc);

    return DefaultTabController(
      length: 2,
      child: Drawer(
        width: MediaQuery.sizeOf(context).width * 0.82,
        child: Column(
          children: [
            Container(
              color: readerTheme.surfaceColor,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.chapterList,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: tc,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(PhosphorIconsRegular.x, color: tc),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: l10n.close,
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      labelColor: tc,
                      unselectedLabelColor: tc.withValues(alpha: 0.45),
                      indicatorColor: tc,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 14),
                      tabs: [
                        Tab(text: l10n.chapterList),
                        Tab(text: l10n.bookmarks),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ChapterListWidget(
                    chapters: chapters,
                    currentChapterIndex: currentChapterIndex,
                    onChapterSelected: (i) {
                      Navigator.of(context).pop();
                      onChapterSelected(i);
                    },
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  _BookmarkTab(
                    bookmarks: bookmarks,
                    bookId: bookId,
                    textColor: tc,
                    dimColor: dim,
                    accentColor: readerTheme.accentColor,
                    onBookmarkSelected: onBookmarkSelected,
                    onAddBookmark: onAddBookmark,
                    onDeleteBookmark: onDeleteBookmark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================

class _BookmarkTab extends StatelessWidget {
  final List<Bookmark> bookmarks;
  final String bookId;
  final Color textColor, dimColor, accentColor;
  final ValueChanged<Bookmark> onBookmarkSelected;
  final VoidCallback? onAddBookmark;
  final ValueChanged<String> onDeleteBookmark;

  const _BookmarkTab({
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
              style: TextStyle(fontSize: 13, color: dimColor),
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
                  style: TextStyle(fontSize: 13, color: dimColor),
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
                  style: TextStyle(fontSize: 13, color: accentColor),
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
