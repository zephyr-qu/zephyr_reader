library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ChapterListWidget extends StatelessWidget {
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final ThemeMode themeMode;
  final ValueChanged<int> onChapterSelected;
  final VoidCallback onClose;

  const ChapterListWidget({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.themeMode,
    required this.onChapterSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor(themeMode);
    final backgroundColor = _getBackgroundColor(themeMode);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: textColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '目录',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${chapters.length} 章',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isCurrent = chapter.chapterIndex == currentChapterIndex;

                  final indent = (chapter.level - 1) * 16.0;

                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + indent.clamp(0, 64),
                      right: 16.0,
                    ),
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        color: isCurrent ? Colors.blue : textColor,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: isCurrent
                        ? Text(
                            '当前章节',
                            style: TextStyle(
                              color: Colors.blue.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          )
                        : null,
                    onTap: () => onChapterSelected(chapter.chapterIndex),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTextColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return Colors.grey[300]!;
      case ThemeMode.light:
      default:
        return Colors.black87;
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF1a1a1a);
      case ThemeMode.light:
      default:
        return const Color(0xFFF5F5DC);
    }
  }
}

