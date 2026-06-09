import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart' as backup_api;
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';

/// 备份状态卡片。
///
/// 显示当前数据库的行数统计概览。
class BackupStatusCard extends HookWidget {
  final BackupViewModel vm;

  const BackupStatusCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final DateTime? lastAt = useSignalValue(vm.lastBackupAt);
    final BackupStatus status = useSignalValue(vm.status);
    final String? errorMsg = useSignalValue<String?, Signal<String?>>(
      vm.errorMessage,
    );
    final AsyncState<backup_api.BackupStats?> currentStats = useSignalValue(
      vm.currentStats,
    );
    final (icon, color, statusText) = switch (status) {
      BackupStatus.exporting => (
        PhosphorIconsRegular.arrowsClockwise,
        cs.primary,
        '备份中…',
      ),
      BackupStatus.restoring => (
        PhosphorIconsRegular.arrowsClockwise,
        cs.tertiary,
        '恢复中…',
      ),
      BackupStatus.error => (
        PhosphorIconsRegular.warningCircle,
        cs.error,
        '操作失败：${errorMsg ?? "未知错误"}',
      ),
      _ => (
        lastAt != null
            ? PhosphorIconsRegular.cloudCheck
            : PhosphorIconsRegular.cloudSlash,
        lastAt != null ? cs.primary : cs.onSurfaceVariant,
        lastAt != null ? '上次备份：${_formatAgo(lastAt)}' : '尚未进行过备份',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (status == BackupStatus.idle && lastAt != null)
                  const SizedBox(height: 2),
                if (status == BackupStatus.idle && lastAt != null)
                  Text(
                    '数据量：${currentStats.value?.books ?? "?"} 本书 · '
                    '${currentStats.value?.notes ?? "?"} 条笔记',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${(diff.inDays / 30).floor()} 个月前';
  }
}
