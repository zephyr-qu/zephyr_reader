import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_dialogs.dart';

/// 书架批量操作工具栏。
///
/// 在批量选择模式下显示，提供分类、删除等批量操作按钮。
class BookshelfBatchToolbar extends StatelessWidget {
  final int selectedCount;
  final List<Category> categories;
  final VoidCallback onCancel;
  final Future<void> Function() onDeleteAll;
  final Future<void> Function(String status) onBatchStatusChange;
  final Future<void> Function(List<String> categoryIds) onBatchCategoryChange;

  const BookshelfBatchToolbar({
    super.key,
    required this.selectedCount,
    required this.categories,
    required this.onCancel,
    required this.onDeleteAll,
    required this.onBatchStatusChange,
    required this.onBatchCategoryChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: Spacing.sm.value,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(l10n.selectedBooksCount(selectedCount)),
            const Spacer(),
            TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(l10n.deleteBook),
                      content: Text(l10n.batchDeleteConfirm(selectedCount)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await onDeleteAll();
                  }
                } else if (action == 'category') {
                  final selected = await showCategorySelectionDialog(
                    context,
                    categories: categories,
                    title: l10n.moveCategory,
                    cancelText: l10n.cancel,
                    confirmText: l10n.apply,
                  );
                  if (selected != null && selected.isNotEmpty) {
                    await onBatchCategoryChange(selected.toList());
                  }
                } else if (action == 'status') {
                  final status = await showDialog<String>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text(l10n.changeStatus),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: Text(l10n.reading),
                            onTap: () => Navigator.pop(c, 'reading'),
                          ),
                          ListTile(
                            title: Text(l10n.notStarted),
                            onTap: () => Navigator.pop(c, 'planned'),
                          ),
                          ListTile(
                            title: Text(l10n.finished),
                            onTap: () => Navigator.pop(c, 'completed'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (status != null) {
                    await onBatchStatusChange(status);
                  }
                }
              },
              itemBuilder: (c) => [
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      PhosphorIconsRegular.trash,
                      color: MenuItemSemantic.error.iconColor(theme.brightness),
                    ),
                    title: Text(
                      l10n.delete,
                      style: TextStyle(
                        color: MenuItemSemantic.error.iconColor(
                          theme.brightness,
                        ),
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'category',
                  child: ListTile(
                    leading: const Icon(PhosphorIconsRegular.folders),
                    title: Text(l10n.moveCategory),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    leading: const Icon(PhosphorIconsRegular.checkCircle),
                    title: Text(l10n.changeStatus),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
