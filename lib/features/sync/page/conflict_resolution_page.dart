/// 冲突解决页面
///
/// 显示同步冲突并允许用户选择解决策略
library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../application/services/webdav_sync_service.dart';

/// 冲突解决页面
class ConflictResolutionPage extends HookWidget {
  final EnhancedWebDavSyncService syncService;
  final ConflictInfo conflictInfo;
  final Function(ConflictResolution resolution)? onResolved;

  const ConflictResolutionPage({
    super.key,
    required this.syncService,
    required this.conflictInfo,
    this.onResolved,
  });

  @override
  Widget build(BuildContext context) {
    final isResolving = useState(false);
    final selectedResolution = useState<ConflictResolution?>(null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('解决同步冲突'),
        actions: [
          if (selectedResolution.value != null)
            IconButton(
              icon: const Icon(PhosphorIconsBold.check),
              onPressed: () => _resolveConflict(
                context,
                selectedResolution.value!,
                isResolving,
              ),
              tooltip: '确认解决',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 冲突信息卡片
            _buildConflictInfoCard(conflictInfo),
            const SizedBox(height: 24),
            // 解决策略选择
            _buildResolutionOptions(context, selectedResolution, conflictInfo),
            const SizedBox(height: 24),
            // 数据对比
            _buildDataComparison(context, conflictInfo),
            const SizedBox(height: 24),
            // 帮助信息
            _buildHelpCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictInfoCard(ConflictInfo conflictInfo) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIconsFill.warning,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '检测到数据冲突',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '数据类型：${_getDataTypeName(conflictInfo.dataType)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '本地修改时间：${_formatDateTime(conflictInfo.localModified)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '远程修改时间：${_formatDateTime(conflictInfo.remoteModified)}',
              style: const TextStyle(fontSize: 14),
            ),
            if (conflictInfo.autoResolution != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.sparkle,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '建议：${_getResolutionName(conflictInfo.autoResolution!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOptions(
    BuildContext context,
    ValueNotifier<ConflictResolution?> selectedResolution,
    ConflictInfo conflictInfo,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择解决策略',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildResolutionOption(
              context,
              ConflictResolution.useLocal,
              '使用本地版本',
              '将本地数据上传到服务器，覆盖远程版本',
              PhosphorIconsRegular.cloudArrowUp,
              Colors.blue,
              selectedResolution,
            ),
            const SizedBox(height: 12),
            _buildResolutionOption(
              context,
              ConflictResolution.useRemote,
              '使用远程版本',
              '从服务器下载数据，覆盖本地版本',
              PhosphorIconsRegular.cloudArrowDown,
              Colors.green,
              selectedResolution,
            ),
            const SizedBox(height: 12),
            _buildResolutionOption(
              context,
              ConflictResolution.merge,
              '合并两个版本',
              '智能合并本地和远程数据（推荐）',
              PhosphorIconsRegular.gitMerge,
              Colors.orange,
              selectedResolution,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResolutionOption(
    BuildContext context,
    ConflictResolution resolution,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    ValueNotifier<ConflictResolution?> selectedResolution,
  ) {
    final isSelected = selectedResolution.value == resolution;

    return InkWell(
      onTap: () {
        selectedResolution.value = resolution;
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(PhosphorIconsFill.checkCircle, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildDataComparison(BuildContext context, ConflictInfo conflictInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据对比',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(PhosphorIconsRegular.deviceMobile, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '本地数据',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          conflictInfo.localPreview,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '修改时间：${_formatDateTime(conflictInfo.localModified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(PhosphorIconsRegular.cloud, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '远程数据',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          conflictInfo.remotePreview,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '修改时间：${_formatDateTime(conflictInfo.remoteModified)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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
              '解决策略说明',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              '使用本地版本',
              '当您在本地设备上进行了重要修改，且希望保留这些修改时使用。远程数据将被覆盖。',
              PhosphorIconsRegular.info,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              '使用远程版本',
              '当远程数据是最新的，或者您希望放弃本地修改时使用。本地数据将被覆盖。',
              PhosphorIconsRegular.info,
            ),
            const SizedBox(height: 12),
            _buildHelpItem(
              '合并两个版本',
              '系统会智能合并本地和远程的数据。适用于两个设备都有不同修改的场景。',
              PhosphorIconsRegular.sparkle,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.lightbulb,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提示：系统会根据数据类型和修改时间自动推荐最佳解决策略',
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

  Future<void> _resolveConflict(
    BuildContext context,
    ConflictResolution resolution,
    ValueNotifier<bool> isResolving,
  ) async {
    isResolving.value = true;

    try {
      final success = await syncService.resolveConflict(
        conflictInfo: conflictInfo,
        resolution: resolution,
      );

      if (!context.mounted) return;

      if (success) {
        Navigator.of(context).pop(resolution);
        onResolved?.call(resolution);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('冲突已解决'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('解决冲突失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解决冲突异常：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      isResolving.value = false;
    }
  }

  String _getDataTypeName(SyncDataType type) {
    switch (type) {
      case SyncDataType.readingProgress:
        return '阅读进度';
      case SyncDataType.bookmarks:
        return '书签';
      case SyncDataType.bookshelf:
        return '书架';
      case SyncDataType.settings:
        return '设置';
    }
  }

  String _getResolutionName(ConflictResolution resolution) {
    switch (resolution) {
      case ConflictResolution.useLocal:
        return '使用本地版本';
      case ConflictResolution.useRemote:
        return '使用远程版本';
      case ConflictResolution.merge:
        return '合并两个版本';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
