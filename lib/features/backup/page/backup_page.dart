import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_action_tile.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_status_card.dart';
import 'package:zephyr_reader/features/backup/page/widgets/restore_confirm_dialog.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_stats_section.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

/// 数据备份与还原页面。
///
/// 支持导出数据库备份、导入备份文件还原数据，
/// 以及管理自动快照。
class BackupPage extends HookWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<BackupViewModel>());
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    useEffect(() {
      vm.initialize();
      return null;
    }, []);
    final AsyncState<BackupStats?> currentStats = useSignalValue(
      vm.currentStats,
    );
    final DateTime? lastBackupAt = useSignalValue(vm.lastBackupAt);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupRestore),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= LayoutBreakpoints.expandedMin
              ? LayoutBreakpoints.expandedMin
              : LayoutBreakpoints.compactMax;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  BackupStatusCard(vm: vm),
                  const SizedBox(height: 20),
                  BackupActionTile(
                    icon: PhosphorIconsRegular.cloudArrowUp,
                    iconBackground: cs.primaryContainer,
                    iconColor: cs.onPrimaryContainer,
                    title: l10n.backup,
                    subtitle: _backupSubtitle(lastBackupAt, l10n),
                    onTap: () => _performBackup(context, vm),
                  ),
                  const SizedBox(height: 8),
                  BackupActionTile(
                    icon: PhosphorIconsRegular.cloudArrowDown,
                    iconBackground: cs.secondaryContainer,
                    iconColor: cs.onSecondaryContainer,
                    title: l10n.restoreTitle,
                    subtitle: l10n.restoreSubtitle,
                    onTap: () => _performRestore(context, vm),
                  ),
                  const SizedBox(height: 20),
                  BackupStatsSection(stats: currentStats.value),
                ].animate().fadeIn(duration: 300.ms),
              ),
            ),
          );
        },
      ),
    );
  }

  String _backupSubtitle(DateTime? at, AppLocalizations l10n) {
    if (at == null) return l10n.backupSubtitleNever;
    final diff = DateTime.now().difference(at);
    if (diff.inDays > 0) return l10n.backupSubtitleDays(diff.inDays);
    if (diff.inHours > 0) return l10n.backupSubtitleHours(diff.inHours);
    if (diff.inMinutes > 0) return l10n.backupSubtitleMinutes(diff.inMinutes);
    return l10n.backupSubtitleJustNow;
  }

  Future<void> _performBackup(BuildContext context, BackupViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    await vm.performBackup();
    if (!context.mounted) return;

    if (vm.status.value == BackupStatus.exportingDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.backupSuccess),
          // 使用默认 SnackBar 背景色
        ),
      );
    } else if (vm.status.value == BackupStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.backupFailed(vm.errorMessage.value ?? '')),
          // 使用默认 SnackBar 背景色
        ),
      );
    }
    await vm.dismissResult();
  }

  Future<void> _performRestore(BuildContext context, BackupViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final filePath = await _pickBackupFile();
    if (filePath == null) return;
    if (!context.mounted) return;

    final manifest = await inspectBackup(backupPath: filePath);
    if (!context.mounted) return;
    if (manifest == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.restoreFailed(''))));
      return;
    }

    final confirmed = await showRestoreConfirmDialog(context, manifest);
    if (confirmed != true) return;
    if (!context.mounted) return;

    await vm.performRestore(filePath, manifest);
    if (!context.mounted) return;

    if (vm.status.value == BackupStatus.restoringDone) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.restoreSuccess}。${l10n.restoreRestartNotice}'),
          duration: const Duration(seconds: 8),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (vm.status.value == BackupStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.restoreFailed(vm.errorMessage.value ?? '')),
          // 使用默认 SnackBar 背景色
        ),
      );
    }
    await vm.dismissResult();
  }

  Future<String?> _pickBackupFile() async {
    final result = await FilePicker.pickFile(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    return result?.path;
  }
}
