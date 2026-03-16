/// ?��????�?????�?????�??��
library;

import 'package:flutter/material.dart';

/// ?��????�?????�?????�??��
class ReaderToolbar extends StatelessWidget {
  final String title;
  final ThemeMode themeMode;
  final VoidCallback onClose;
  final VoidCallback onToggleToolbar;
  final VoidCallback onShowChapterList;
  final VoidCallback onShowBookmarks;

  const ReaderToolbar({
    super.key,
    required this.title,
    required this.themeMode,
    required this.onClose,
    required this.onToggleToolbar,
    required this.onShowChapterList,
    required this.onShowBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = themeMode == ThemeMode.dark
        ? Colors.black87
        : Colors.white;

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.list),
                  onPressed: onShowChapterList,
                  tooltip: '?�???�',
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border),
                  onPressed: onShowBookmarks,
                  tooltip: '??????',
                ),
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: onToggleToolbar,
                  tooltip: '?��?��????�??�?',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
