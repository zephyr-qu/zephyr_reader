/// 书签管理组件。
library;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                    l10n.addBookmark,
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
                        _showAddBookmarkDialog(context, textColor, l10n);
                      }
                    },
                    tooltip: l10n.addBookmark,
                  ),
                  SizedBox(width: DesignTokens.spacing(Spacing.md)),
                  IconButton(
                    icon: Icon(PhosphorIconsLight.x, color: textColor),
                    onPressed: onClose,
                    tooltip: l10n.close,
                  ),
                ],
              ),
            ),
            // 书签列表
            Expanded(
              child: bookmarks.isEmpty
                  ? _buildEmptyState(textColor, l10n)
                  : ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = bookmarks[index];
                        return _buildBookmarkItem(bookmark, textColor, l10n);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, AppLocalizations l10n) {
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
            l10n.noBookmarks,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
            ),
          ),
          SizedBox(height: DesignTokens.spacing(Spacing.sm)),
          Text(
            l10n.addBookmarkHint,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(Bookmark bookmark, Color textColor, AppLocalizations l10n) {
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
          bookmark.title.isNotEmpty ? bookmark.title : l10n.addBookmark,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chapterN(bookmark.chapterIndex + 1),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            Text(
              '${l10n.charOffset}: ${bookmark.charOffset}',
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
              tooltip: l10n.jumpTo,
            ),
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(PhosphorIconsRegular.trash, color: Colors.red),
                onPressed: () => _showDeleteConfirm(context, bookmark, l10n),
                tooltip: l10n.delete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBookmarkDialog(BuildContext context, Color textColor, AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addBookmark),
        content: Text(l10n.confirmAddBookmark),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: TextStyle(color: textColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAddBookmark?.call();
              hapticFeedback(HapticType.medium);
              showInfoSnack(context, l10n.bookmarkAdded);
            },
            child: Text(l10n.add),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Bookmark bookmark, AppLocalizations l10n) {
    final textColor = _getTextColor(themeMode);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(l10n.confirmDeleteBookmarkSimple),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: TextStyle(color: textColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteBookmark(bookmark.id);
              showInfoSnack(context, l10n.bookmarkDeleted);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
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
