/// 书签管理组件
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书签管理组件
class BookmarkWidget extends StatelessWidget {
  /// 书签列表
  final List<DbBookmark> bookmarks;

  /// 主题模式
  final ThemeMode themeMode;

  /// 书签选中回调
  final ValueChanged<DbBookmark> onBookmarkSelected;

  /// 添加书签回调
  final VoidCallback? onAddBookmark;

  /// 删除书签回调
  final ValueChanged<String> onDeleteBookmark;

  /// 关闭回调
  final VoidCallback onClose;

  const BookmarkWidget({
    super.key,
    required this.bookmarks,
    required this.themeMode,
    required this.onBookmarkSelected,
    this.onAddBookmark,
    required this.onDeleteBookmark,
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
            // 标题栏
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
                    '书签',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, color: textColor),
                    onPressed: () {
                      if (onAddBookmark != null) {
                        _showAddBookmarkDialog(context, textColor);
                      }
                    },
                    tooltip: '添加书签',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
            // 书签列表
            Expanded(
              child: bookmarks.isEmpty
                  ? _buildEmptyState(textColor)
                  : ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return _buildBookmarkItem(bookmark, textColor);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: textColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无书签',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角添加书签',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(DbBookmark bookmark, Color textColor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.bookmark, color: Colors.blue),
        title: Text(
          bookmark.title.isNotEmpty ? bookmark.title : '书签',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '章节 ${bookmark.chapterIndex + 1}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            Text(
              '偏移: ${bookmark.charOffset}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.navigation, color: Colors.blue),
              onPressed: () => onBookmarkSelected(bookmark),
              tooltip: '跳转',
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _showDeleteConfirm(context, bookmark),
                tooltip: '删除',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBookmarkDialog(BuildContext context, Color textColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加书签'),
        content: const Text('确定要在这里添加书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: textColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAddBookmark?.call();
              // 显示成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('书签已添加'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, DbBookmark bookmark) {
    final textColor = _getTextColor(themeMode);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个书签吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: textColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteBookmark(bookmark.id);
              // 显示成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('书签已删除'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
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
