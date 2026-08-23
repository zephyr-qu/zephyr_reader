import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/confirm_action_dialog.dart';
import 'package:zephyr_reader/core/presentation/widgets/danger_section.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/utils/time_formatters.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart';
import 'package:zephyr_reader/features/data/application/backup_view_model.dart';
import 'package:zephyr_reader/features/data/page/restore_confirm_dialog.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

/// 数据管理页面。
///
/// 管理本地数据库备份、还原和应用缓存。
class DataManagementPage extends HookWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final backupVm = useMemoized(() => getIt<BackupViewModel>());
    useEffect(() {
      backupVm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    final l10n = AppLocalizations.of(context)!;
    final DateTime? lastBackupAt = useSignalValue(backupVm.lastBackupAt);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.dataManagement,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 20),
            onPressed: backupVm.initialize,
            tooltip: '刷新',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildBackupSection(cs, l10n, backupVm, lastBackupAt, context),
          const SizedBox(height: 24),
          _buildDangerZone(context),
        ],
      ),
    );
  }

  // ==================== Danger Zone ====================

  Widget _buildDangerZone(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DangerSection(
          label: l10n.dangerZone,
          children: [
            DangerItem(
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              title: l10n.resetAllSettings,
              description: l10n.resetAllSettingsDesc,
              onTap: () => _confirmResetSettings(context),
            ),
            DangerItem(
              icon: PhosphorIconsRegular.broom,
              title: l10n.clearAllData,
              description: l10n.clearAllDataDesc,
              onTap: () => _confirmClearCache(context),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Backup Section ====================

  Widget _buildBackupSection(
    ColorScheme cs,
    AppLocalizations l10n,
    BackupViewModel backupVm,
    DateTime? lastBackupAt,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label: '本地备份'),
        SettingsCard(
          showDividers: true,
          children: [
            SettingsNavigationTile(
              iconWidget: const Icon(
                PhosphorIconsRegular.cloudArrowUp,
                size: 16,
                color: Color(0xFF5C6BC0),
              ),
              iconBackground: const Color(0xFFE8EAF6),
              title: l10n.backup,
              subtitle: _backupSubtitle(lastBackupAt, l10n),
              onTap: () => _performBackup(context, backupVm),
            ),
            SettingsNavigationTile(
              iconWidget: const Icon(
                PhosphorIconsRegular.cloudArrowDown,
                size: 16,
                color: Color(0xFF26A69A),
              ),
              iconBackground: const Color(0xFFE0F2F1),
              title: l10n.restoreTitle,
              subtitle: l10n.restoreSubtitle,
              onTap: () => _performRestore(context, backupVm),
            ),
          ],
        ),
      ],
    );
  }

  String _backupSubtitle(DateTime? at, AppLocalizations l10n) {
    if (at == null) return l10n.neverBackedUp;
    return formatRelativeTime(at, l10n);
  }

  Future<void> _performBackup(BuildContext context, BackupViewModel vm) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.performBackup();
    if (!context.mounted) return;

    switch (result) {
      case BackupResult.success:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.backupSuccess)));
      case BackupResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.backupFailed(vm.errorMessage.value ?? '')),
          ),
        );
      case BackupResult.cancelled:
        break;
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

    final result = await vm.performRestore(filePath, manifest);
    if (!context.mounted) return;

    switch (result) {
      case RestoreResult.success:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.restoreSuccess}。${l10n.restoreRestartNotice}',
            ),
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case RestoreResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.restoreFailed(vm.errorMessage.value ?? '')),
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

  // ==================== Dialogs ====================

  void _confirmClearCache(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showConfirmActionDialog(
      context,
      title: l10n.clearAllDataTitle,
      content: l10n.clearAllDataContent,
      confirmLabel: l10n.confirmClear,
      onConfirm: () async {
        try {
          await SystemCache.clearCache();
          if (!context.mounted) return;
          showInfoSnack(context, l10n.dataCleared);
        } catch (e) {
          if (!context.mounted) return;
          showInfoSnack(context, l10n.dataClearFailed(e.toString()));
        }
      },
    );
  }

  void _confirmResetSettings(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showConfirmActionDialog(
      context,
      title: l10n.confirmReset,
      content: l10n.confirmResetContent,
      confirmLabel: l10n.confirmReset,
      onConfirm: () => getIt<OtherSettingsViewModel>().resetAllSettings(),
    );
  }
}
