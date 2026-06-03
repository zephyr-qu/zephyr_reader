library;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/features/backup/application/backup_view_model.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_action_tile.dart';
import 'package:zephyr_reader/features/backup/page/widgets/backup_status_card.dart';
import 'package:zephyr_reader/features/backup/page/widgets/restore_confirm_dialog.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

class BackupPage extends HookWidget {

  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<BackupViewModel>(), []);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    useEffect(() {
      vm.initialize();
      return;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.backupRestore),
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          BackupStatusCard(vm: vm),
          const SizedBox(height: 20),
          BackupActionTile(
            icon: PhosphorIconsRegular.cloudArrowUp,
            iconBackground: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1976D2),
            title: l10n.backup,
            subtitle: _backupSubtitle(vm, l10n),
            onTap: () => _performBackup(context, vm),
          ),
          const SizedBox(height: 8),
          BackupActionTile(
            icon: PhosphorIconsRegular.cloudArrowDown,
            iconBackground: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            title: '从备份还原',
            subtitle: '选择一个 .db 备份文件恢复数据',
            onTap: () => _performRestore(context, vm),
          ),
          const SizedBox(height: 20),
          _buildStatsSection(context, cs, vm),
        ].animate().fadeIn(duration: 300.ms),
      ),
    );
  }

  String _backupSubtitle(BackupViewModel vm, AppLocalizations l10n) {
    final at = vm.lastBackupAt.value;
    if (at == null) return '从未备份';
    final diff = DateTime.now().difference(at);
    if (diff.inDays > 0) return '${diff.inDays} 天前备份 — 建议立即备份';
    if (diff.inHours > 0) return '${diff.inHours} 小时前备份';
    if (diff.inMinutes > 0) return '${diff.inMinutes} 分钟前备份';
    return '刚刚备份';
  }

  Future<void> _performBackup(BuildContext context, BackupViewModel vm) async {
    await vm.performBackup();
    if (!context.mounted) return;

    if (vm.status.value == BackupStatus.exportingDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('备份成功'), backgroundColor: Colors.green),
      );
    } else if (vm.status.value == BackupStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('备份失败：${vm.errorMessage.value}'), backgroundColor: Colors.red),
      );
    }
    await vm.dismissResult();
  }

  Future<void> _performRestore(BuildContext context, BackupViewModel vm) async {
    final filePath = await _pickBackupFile();
    if (filePath == null) return;
    if (!context.mounted) return;

    final manifest = await inspectBackup(backupPath: filePath);
    if (!context.mounted) return;
    if (manifest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选文件不是有效的备份文件')),
      );
      return;
    }

    final confirmed = await showRestoreConfirmDialog(context, manifest);
    if (confirmed != true) return;
    if (!context.mounted) return;

    await vm.performRestore();
    if (!context.mounted) return;

    if (vm.status.value == BackupStatus.restoringDone) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('恢复成功'),
          content: const Text('数据已还原，请重启应用以生效。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } else if (vm.status.value == BackupStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败：${vm.errorMessage.value}'), backgroundColor: Colors.red),
      );
    }
    await vm.dismissResult();
  }

  Future<String?> _pickBackupFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: '选择备份文件',
      type: FileType.custom,
      allowedExtensions: ['db'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  Widget _buildStatsSection(BuildContext context, ColorScheme cs, BackupViewModel vm) {
    final stats = vm.currentStats.value;
    if (stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前数据统计',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statChip(cs, '${stats.books}', '本书'),
              _statChip(cs, '${stats.notes}', '笔记'),
              _statChip(cs, '${stats.bookmarks}', '书签'),
              _statChip(cs, '${stats.vocabularyWords}', '生词'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(ColorScheme cs, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSecondaryContainer)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
