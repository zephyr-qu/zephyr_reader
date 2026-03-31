/// 书籍卡片组件
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:zephyr_reader/domain/models/book.dart';

import '../../application/services/bookshelf_service.dart';
import '../../application/states/bookshelf_state.dart';

/// 书籍卡片
class BookCard extends StatelessWidget {
  /// 书籍信息
  final Book book;

  /// 视图模式
  final BookshelfViewMode viewMode;

  /// 是否选中
  final bool isSelected;

  /// 是否处于选择模式
  final bool selectingMode;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  const BookCard({
    super.key,
    required this.book,
    required this.viewMode,
    this.isSelected = false,
    this.selectingMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (viewMode == BookshelfViewMode.grid) {
      return _buildGridCard(context);
    } else {
      return _buildListCard(context);
    }
  }

  Widget _buildGridCard(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域
            Expanded(
              child: Stack(
                children: [
                  // 封面图片
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: _buildCoverImage(context),
                  ),
                  // 选中遮罩
                  if (selectingMode)
                    Positioned.fill(
                      child: Container(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.3)
                            : theme.colorScheme.surface.withValues(alpha: 0.5),
                        child: isSelected
                            ? const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              )
                            : null,
                      ),
                    ),
                  // 进度标签
                  if (book.progress > 0 && !selectingMode)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: book.progress,
                        minHeight: 3,
                        backgroundColor: theme.colorScheme.outlineVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 书籍信息
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名
                  Text(
                    book.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 作
                  Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 进度百分
                  Row(
                    children: [
                      Icon(
                        Icons.bookmark_outline,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(book.progress * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      // 格式标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getFormatColor(theme).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.fileType.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getFormatColor(theme),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 选择
            if (selectingMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            // 封面缩略
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildCoverImage(context, width: 60, height: 80),
            ),
            const SizedBox(width: 16),
            // 书籍信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名
                  Text(
                    book.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 作
                  Text(
                    book.author,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 进度和格
                  Row(
                    children: [
                      // 进度
                      Expanded(
                        child: LinearProgressIndicator(
                          value: book.progress,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${(book.progress * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 格式标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getFormatColor(theme).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          book.fileType.toUpperCase(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getFormatColor(theme),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 最后阅读时
                  if (book.lastReadAt != null)
                    Text(
                      '阅读${DateFormat('MM-dd HH:mm').format(book.lastReadAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // 更多操作
            if (!selectingMode)
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'detail':
                      // 跳转到书籍详情页
                      if (onTap != null) onTap!();
                      break;
                    case 'rename':
                      // 显示重命名对话框
                      await _showRenameDialog(context, book);
                      break;
                    case 'delete':
                      // 显示删除确认对话
                      await _showDeleteConfirm(context, book);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'detail',
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('详情'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('重命'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('删除'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(
    BuildContext context, {
    double? width,
    double? height,
  }) {
    if (book.coverPath != null && book.coverPath!.isNotEmpty) {
      return Image.file(
        File(book.coverPath!),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultCover(context, width: width, height: height);
        },
      );
    }
    return _buildDefaultCover(context, width: width, height: height);
  }

  Widget _buildDefaultCover(
    BuildContext context, {
    double? width,
    double? height,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.book_outlined,
          size: width != null ? width * 0.5 : 32,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Color _getFormatColor(ThemeData theme) {
    switch (book.fileType) {
      case 'txt':
        return theme.colorScheme.primary;
      case 'epub':
        return theme.colorScheme.secondary;
      case 'pdf':
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  /// 显示重命名对话框
  Future<void> _showRenameDialog(BuildContext context, Book book) async {
    final controller = TextEditingController(text: book.title);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '书名',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      // 调用服务更新书名
      final bookshelfService = GetIt.I.get<BookshelfService>();
      final updated = await bookshelfService.updateBookTitle(
        book.id,
        controller.text,
      );

      if (updated) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('书名已更新')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('更新失败')));
      }
    }
  }

  /// 显示删除确认对话
  Future<void> _showDeleteConfirm(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除"${book.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 调用服务删除书籍
      final bookshelfService = GetIt.I.get<BookshelfService>();
      final deleted = await bookshelfService.deleteBook(book.id);

      if (deleted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('书籍已删除')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }
}
