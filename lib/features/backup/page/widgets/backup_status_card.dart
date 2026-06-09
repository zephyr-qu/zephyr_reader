import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart' as backup_api;
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';

/// 备份状态卡片。
///
/// 显示当前备份状态和数据库行数统计概览。
class BackupStatusCard extends HookWidget {
  final BackupViewModel vm;

  const BackupStatusCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
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
        l10n.backingUp,
      ),
      BackupStatus.restoring => (
        PhosphorIconsRegular.arrowsClockwise,
        cs.tertiary,
        l10n.restoring,
      ),
      BackupStatus.error => (
        PhosphorIconsRegular.warningCircle,
        cs.error,
        l10n.operationFailed(errorMsg ?? l10n.unknownError),
      ),
      _ => (
        lastAt != null
            ? PhosphorIconsRegular.cloudCheck
            : PhosphorIconsRegular.cloudSlash,
        lastAt != null ? cs.primary : cs.onSurfaceVariant,
        lastAt != null
            ? l10n.lastBackup(_formatAgo(lastAt, l10n))
            : l10n.neverBackedUp,
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                if (status == BackupStatus.idle && lastAt != null)
                  const SizedBox(height: 2),
                if (status == BackupStatus.idle && lastAt != null)
                  Text(
                    l10n.dataSummary(
                      '${currentStats.value?.books ?? "?"}',
                      '${currentStats.value?.notes ?? "?"}',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAgo(DateTime dt, AppLocalizations l10n) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return l10n.backupSubtitleJustNow;
    if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays < 30) return l10n.timeDaysAgo(diff.inDays);
    return l10n.timeMonthsAgo((diff.inDays / 30).floor());
  }
}
