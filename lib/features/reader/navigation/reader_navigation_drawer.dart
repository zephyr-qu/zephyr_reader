import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/page/navigation/bookmark_list.dart';
import 'package:zephyr_reader/features/reader/page/navigation/chapter_list.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final tc = readerTheme.textColor;
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
                  ChapterList(
                    chapters: chapters,
                    currentChapterIndex: currentChapterIndex,
                    onChapterSelected: (i) {
                      Navigator.of(context).pop();
                      onChapterSelected(i);
                    },
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  BookmarkList(
                    bookmarks: bookmarks,
                    bookId: bookId,
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
