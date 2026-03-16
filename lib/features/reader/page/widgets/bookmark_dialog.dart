/// 书签对话�?
library;

import 'package:flutter/material.dart';

/// 书签对话�?
class BookmarkDialog extends StatelessWidget {
  final List<Map<String, dynamic>> bookmarks;
  final int currentChapterId;
  final int currentPageIndex;
  final VoidCallback? onAddBookmark;
  final ValueChanged<int>? onBookmarkSelected;
  final ValueChanged<int>? onBookmarkDeleted;

  const BookmarkDialog({
    super.key,
    required this.bookmarks,
    required this.currentChapterId,
    required this.currentPageIndex,
    this.onAddBookmark,
    this.onBookmarkSelected,
    this.onBookmarkDeleted,
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
                    '书签',
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
            // 添加书签按钮
            if (onAddBookmark != null)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('添加书签'),
                subtitle: Text(
                  '�?{currentChapterId + 1}�?�?{currentPageIndex + 1}�?',
                ),
                onTap: () {
                  onAddBookmark?.call();
                  Navigator.pop(context);
                },
              ),
            const Divider(height: 1),
            // 书签列表
            Expanded(
              child: bookmarks.isEmpty
                  ? const Center(child: Text('暂无书签'))
                  : ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return ListTile(
                          leading: const Icon(Icons.bookmark),
                          title: Text(bookmark['title'] ?? '书签'),
                          subtitle: Text(
                            '�?{bookmark['chapterId'] + 1}�?�?{bookmark['pageIndex'] + 1}�?',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () {
                              onBookmarkDeleted?.call(bookmark['id'] as int);
                              Navigator.pop(context);
                            },
                          ),
                          onTap: () {
                            onBookmarkSelected?.call(bookmark['id'] as int);
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
