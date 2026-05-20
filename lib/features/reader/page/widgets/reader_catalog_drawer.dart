library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'chapter_list_widget.dart';

class ReaderCatalogDrawer extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ThemeMode themeMode;
  final ValueChanged<int> onChapterSelected;

  const ReaderCatalogDrawer({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.themeMode,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      child: ChapterListWidget(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        themeMode: themeMode,
        onChapterSelected: (index) {
          Navigator.of(context).pop();
          onChapterSelected(index);
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
