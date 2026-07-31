import 'package:zephyr_reader/src/rust/domain/chapter/models.dart';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/navigation/chapter_list.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Reader navigation drawer — chapters only (MVP).
class ReaderNavigationDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;
  final ThemeMode themeMode;
  final String bookId;

  const ReaderNavigationDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
    required this.themeMode,
    required this.bookId,
  });
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final tc = readerTheme.textColor;
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      child: Column(
        children: [
          Container(
            color: readerTheme.surfaceColor,
            child: SafeArea(
              bottom: false,
              child: Padding(
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
            ),
          ),
          Expanded(
            child: ChapterList(
              chapters: chapters,
              currentChapterIndex: currentChapterIndex,
              onChapterSelected: (i) {
                Navigator.of(context).pop();
                onChapterSelected(i);
              },
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
