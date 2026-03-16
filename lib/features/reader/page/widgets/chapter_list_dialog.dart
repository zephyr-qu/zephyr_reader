/// 章节列表对话�?
 library;

import 'package:flutter/material.dart';

/// 章节列表对话�?
class ChapterListDialog extends StatelessWidget {
  final List<Map<String, dynamic>> chapters;
  final int currentChapterId;
  final ValueChanged<int> onChapterSelected;

  const ChapterListDialog({
    super.key,
    required this.chapters,
    required this.currentChapterId,
    required this.onChapterSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          children: [
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '目录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 章节列表
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  final isSelected = chapter['id'] == currentChapterId;

                  return ListTile(
                    title: Text(
                      chapter['title'] ?? '未知章节',
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    onTap: () {
                      onChapterSelected(chapter['id'] as int);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
