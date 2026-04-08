/// 备份对话框
///
/// 提供创建备份的对话框组件
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/sync/application/services/backup_service_types.dart';

/// 显示创建备份对话框
Future<void> showCreateBackupDialog(BuildContext context) async {
  final selectedTypes = useSignal<List<BackupType>>([BackupType.all]);
  final noteController = useTextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('创建备份'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择备份内容：'),
                const SizedBox(height: 8),
                ...BackupType.values.map((type) {
                  return CheckboxListTile(
                    title: Text(_getBackupTypeName(type)),
                    value: selectedTypes.value.contains(type),
                    onChanged: (value) {
                      if (value == true) {
                        if (type == BackupType.all) {
                          selectedTypes.value = [BackupType.all];
                        } else {
                          selectedTypes.value = [
                            ...selectedTypes.value.where(
                              (t) => t != BackupType.all,
                            ),
                            type,
                          ];
                        }
                      } else {
                        selectedTypes.value = selectedTypes.value
                            .where((t) => t != type)
                            .toList();
                      }
                      setDialogState(() {});
                    },
                  );
                }),
                const Divider(),
                const Text('备注（可选）：'),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    hintText: '输入备份备注信息',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 50,
                ),
              ],
            ),
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
        );
      },
    ),
  );

  if (result == true) {
    // 用户确认，执行备份
    // 实际备份逻辑在设置页面中处理
  }
}

String _getBackupTypeName(BackupType type) {
  switch (type) {
    case BackupType.all:
      return '全部数据';
    case BackupType.readingProgress:
      return '阅读进度';
    case BackupType.bookmarks:
      return '书签';
    case BackupType.bookshelf:
      return '书架';
    case BackupType.settings:
      return '设置';
  }
}

/// 显示恢复备份对话框
Future<BackupInfo?> showRestoreBackupDialog(
  BuildContext context,
  List<BackupInfo> backups,
) async {
  if (backups.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无备份记录')));
    }
    return null;
  }

  BackupInfo? selectedBackup;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('选择备份'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: backups.length,
          itemBuilder: (context, index) {
            final backup = backups[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text('备份 ${backup.createdAtFormatted}'),
                subtitle: Text(
                  '${backup.fileSizeFormatted} · ${backup.types.map((t) => _getBackupTypeName(t)).join(', ')}',
                ),
                leading: const Icon(Icons.backup),
                trailing: selectedBackup?.id == backup.id
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  selectedBackup = backup;
                  Navigator.pop(context, true);
                },
              ),
            );
          },
        ),
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

  if (result == true) {
    return selectedBackup;
  }

  return null;
}

/// 显示恢复确认对话框
Future<bool> showRestoreConfirmDialog(
  BuildContext context,
  BackupInfo backup,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('恢复备份'),
      content: Text(
        '确定要从备份 ${backup.createdAtFormatted} 恢复数据吗？\n\n注意：恢复操作将覆盖当前的数据，请谨慎操作。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('恢复'),
        ),
      ],
    ),
  );

  return result == true;
}

/// 显示删除备份确认对话框
Future<bool> showDeleteBackupDialog(
  BuildContext context,
  BackupInfo backup,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('删除备份'),
      content: Text('确定要删除备份 ${backup.createdAtFormatted} 吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('删除'),
        ),
      ],
    ),
  );

  return result == true;
}
