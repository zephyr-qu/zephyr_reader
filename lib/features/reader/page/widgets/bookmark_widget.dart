/// 书签管理组件。
library;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书签管理组件
class BookmarkWidget extends StatelessWidget {
  /// 书签列表
  final List<Bookmark> bookmarks;

  /// 主题模式
  final ThemeMode themeMode;

  /// 书签选中回调
  final ValueChanged<Bookmark> onBookmarkSelected;

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
              padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
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
                    icon: Icon(PhosphorIconsRegular.plus, color: textColor),
                    onPressed: () {
                      if (onAddBookmark != null) {
                        _showAddBookmarkDialog(context, textColor);
                      }
                    },
                    tooltip: '添加书签',
                  ),
                  SizedBox(width: DesignTokens.spacing(Spacing.md)),
                  IconButton(
                    icon: Icon(PhosphorIconsLight.x, color: textColor),
                    onPressed: onClose,
                    tooltip: '关闭',
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
            PhosphorIconsRegular.bookmarkSimple,
            size: 64,
            color: textColor.withValues(alpha: 0.3),
          ),
          SizedBox(height: DesignTokens.spacing(Spacing.md)),
          Text(
            '暂无书签',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          SizedBox(height: DesignTokens.spacing(Spacing.sm)),
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

  Widget _buildBookmarkItem(Bookmark bookmark, Color textColor) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing(Spacing.md),
        vertical: DesignTokens.spacing(Spacing.sm),
      ),
      child: ListTile(
        leading: const Icon(
          PhosphorIconsFill.bookmarkSimple,
          color: Colors.blue,
        ),
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
              icon: const Icon(
                PhosphorIconsRegular.compass,
                color: Colors.blue,
              ),
              onPressed: () => onBookmarkSelected(bookmark),
              tooltip: '跳转',
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(PhosphorIconsRegular.trash, color: Colors.red),
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
    showDialog<void>(
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
              hapticFeedback(HapticType.medium);
              // 显示成功提示
              showInfoSnack(context, '书签已添加');
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Bookmark bookmark) {
    final textColor = _getTextColor(themeMode);

    showDialog<void>(
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
              showInfoSnack(context, '书签已删除');
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
