/// 备份与恢复页面
///
/// 提供数据备份和恢复功能
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../core/utils/logging.dart';
import '../application/services/advanced_webdav_sync_service.dart';

/// 备份与恢复页面
class BackupRestorePage extends HookWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = useMemoized(() => AdvancedWebDavSyncService());
    final backups = useState<List<BackupInfo>>([]);
    final isBackingUp = useState(false);
    final isRestoring = useState(false);
    final restoringBackup = useState<BackupInfo?>(null);

    useEffect(() {
      _loadBackups(syncService, backups);
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('备份与恢复'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadBackups(syncService, backups),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 创建备份卡片
            _buildCreateBackupCard(syncService, context, isBackingUp, backups),
            const SizedBox(height: 24),
            _buildBackupListCard(syncService, context, backups,
              isRestoring,
              restoringBackup,
            ),
            const SizedBox(height: 24),
            // 备份说明
            _buildHelpCard(context),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBackups(
    AdvancedWebDavSyncService syncService,
    ValueNotifier<List<BackupInfo>> backups,
  ) async {
    try {
      final backupList = syncService.getBackups();
      backups.value = backupList;
    } catch (e) {
      Logging.debug('加载备份列表失败：$e');
      backups.value = [];
    }
  }

  Widget _buildCreateBackupCard(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    ValueNotifier<bool> isBackingUp,
    ValueNotifier<List<BackupInfo>> backups,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  '创建备份',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '创建当前所有数据的完整备份，包括阅读进度、书签、书架和设置',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
                child: ElevatedButton.icon(
                onPressed: isBackingUp.value
                    ? null
                    : () => _createBackup(syncService, context, isBackingUp, backups),
                icon: isBackingUp.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.backup),
                label: Text(isBackingUp.value ? '正在创建备份...' : '立即备份'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupListCard(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    ValueNotifier<List<BackupInfo>> backups,
    ValueNotifier<bool> isRestoring,
    ValueNotifier<BackupInfo?> restoringBackup,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '备份历史',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<List<BackupInfo>>(
              valueListenable: backups,
              builder: (context, backupList, _) {
                if (backupList.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('暂无备份记录'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: backupList.length,
                  itemBuilder: (context, index) {
                    if (index >= backupList.length) {
                      return const SizedBox.shrink();
                    }
                    final backup = backupList[index];
                    return Column(
                      children: [
                        _buildBackupListItem(
                          syncService, context, backup, isRestoring, restoringBackup,
                        ),
                        if (index < backupList.length - 1)
                          const Divider(height: 1),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupListItem(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    BackupInfo backup,
    ValueNotifier<bool> isRestoring,
    ValueNotifier<BackupInfo?> restoringBackup,
  ) {
    final isCurrentRestoring = restoringBackup.value?.id == backup.id;
    final isRestoringThis = isRestoring.value && isCurrentRestoring;

    return ListTile(
      leading: Icon(
        Icons.folder,
        color: isRestoringThis ? Colors.orange : Colors.blue,
      ),
      title: Text(backup.formattedTime),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${backup.includedDataTypes.length} 个数据类型'),
          Text(backup.formattedSize),
          if (backup.note != null)
            Text(
              backup.note!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'restore') {
            _restoreBackup(syncService, context, backup, isRestoring, restoringBackup);
          } else if (value == 'delete') {
            _deleteBackup(syncService, context, backup);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'restore',
            child: Row(
              children: [Icon(Icons.restore), SizedBox(width: 8), Text('恢复')],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('删除', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '备份说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHelpItem('备份内容', '包括阅读进度、书签、书架和设置等所有数据', Icons.info_outline),
            const SizedBox(height: 12),
            _buildHelpItem('备份位置', '备份文件存储在本地设备，建议定期导出到安全位置', Icons.folder),
            const SizedBox(height: 12),
            _buildHelpItem('恢复数据', '恢复操作会覆盖当前数据，请谨慎操作', Icons.warning_amber),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提示：建议在进行重大操作前（如清除数据、卸载应用）先创建备份',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createBackup(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    ValueNotifier<bool> isBackingUp,
    ValueNotifier<List<BackupInfo>> backups,
  ) async {
    isBackingUp.value = true;

    try {
      final note = await _showNoteDialog(context);
      if (note == null) {
        isBackingUp.value = false;
        return;
      }

      final backupInfo = await syncService.createBackup(note: note);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('备份创建成功：${backupInfo.formattedSize}'),
          backgroundColor: Colors.green,
        ),
      );

      _loadBackups(syncService, backups).ignore();
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份创建失败：$e'), backgroundColor: Colors.red),
      );
    } finally {
      isBackingUp.value = false;
    }
  }

  Future<void> _restoreBackup(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    BackupInfo backup,
    ValueNotifier<bool> isRestoring,
    ValueNotifier<BackupInfo?> restoringBackup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认恢复'),
        content: Text('确定要恢复到 ${backup.formattedTime} 的备份吗？\n\n警告：当前数据将被覆盖！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    isRestoring.value = true;
    restoringBackup.value = backup;

    try {
      final success = await syncService.restoreBackup(backup);

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('备份恢复成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份恢复失败'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份恢复异常：$e'), backgroundColor: Colors.red),
      );
    } finally {
      isRestoring.value = false;
      restoringBackup.value = null;
    }
  }

  Future<void> _deleteBackup(
    AdvancedWebDavSyncService syncService,
    BuildContext context,
    BackupInfo backup,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${backup.formattedTime} 的备份吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await syncService.deleteBackup(backup);

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份已删除'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _showNoteDialog(BuildContext context) async {
    final noteController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备份备注'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            hintText: '可选，例如：更新前备份',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('跳过'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(noteController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    noteController.dispose();
    return result;
  }
}
