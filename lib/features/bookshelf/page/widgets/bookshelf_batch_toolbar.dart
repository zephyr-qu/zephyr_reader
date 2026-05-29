import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: DesignTokens.spacing(Spacing.sm),
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
            Text(
              '已选 $selectedCount 本',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onCancel, child: const Text('取消')),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('删除书籍'),
                      content: Text('确定要删除选中的 $selectedCount 本书吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await onDeleteAll();
                  }
                } else if (action == 'category') {
                  final tempIds = <String>{};
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (c) => StatefulBuilder(
                      builder: (c, setDialogState) => AlertDialog(
                        title: const Text('移动分类'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: categories
                              .map(
                                (cat) => CheckboxListTile(
                                  title: Text(cat.name),
                                  value: tempIds.contains(cat.id),
                                  onChanged: (v) {
                                    if (v == true) {
                                      tempIds.add(cat.id);
                                    } else {
                                      tempIds.remove(cat.id);
                                    }
                                    setDialogState(() {});
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('应用'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (changed == true) {
                    await onBatchCategoryChange(tempIds.toList());
                  }
                } else if (action == 'status') {
                  final status = await showDialog<String>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('更改状态'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text('阅读中'),
                            onTap: () => Navigator.pop(c, 'reading'),
                          ),
                          ListTile(
                            title: const Text('未开始'),
                            onTap: () => Navigator.pop(c, 'planned'),
                          ),
                          ListTile(
                            title: const Text('已读完'),
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
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      PhosphorIconsRegular.trash,
                      color: Colors.red,
                    ),
                    title: Text('删除', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'category',
                  child: ListTile(
                    leading: Icon(PhosphorIconsRegular.folders),
                    title: Text('移动分类'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    leading: Icon(PhosphorIconsRegular.checkCircle),
                    title: Text('更改状态'),
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
