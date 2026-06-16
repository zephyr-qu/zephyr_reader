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
import 'package:zephyr_reader/features/data/application/data_management_view_model.dart';
import 'package:zephyr_reader/features/data/page/widgets/webdav_config_dialog.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/data/application/backup_view_model.dart';
import 'package:zephyr_reader/features/data/page/restore_confirm_dialog.dart';
import 'package:zephyr_reader/src/rust/api/backup.dart';

/// 数据管理页面。
///
/// 支持 WebDAV 协议的阅读数据同步，包括上传备份和下载恢复，
/// 以及本地数据库备份与还原。
/// 使用 [DataManagementViewModel] 管理同步状态。
class DataManagementPage extends HookWidget {
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => DataManagementViewModel());
    final backupVm = useMemoized(() => getIt<BackupViewModel>());
    useEffect(() {
      vm.initialize();
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
            onPressed: () => vm.refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SignalBuilder(
        builder: (context) {
          if (vm.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              _buildStatusHeader(cs, vm, context, l10n),
              const SizedBox(height: 20),
              _buildSyncConfigSection(cs, vm, context),
              const SizedBox(height: 24),
              _buildBackupSection(cs, l10n, backupVm, lastBackupAt, context),
              const SizedBox(height: 24),
              _buildDangerZone(cs, vm, context),
            ],
          );
        },
      ),
    );
  }

  // ==================== Status Header ====================

  Widget _buildStatusHeader(
    ColorScheme cs,
    DataManagementViewModel vm,
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SignalBuilder(
      builder: (context) {
        final syncing = vm.isSyncing.value;
        final configured = vm.isConfigured.value;
        final lastTime = vm.lastSyncTime.value;

        String statusText;
        if (syncing) {
          statusText = '正在同步…';
        } else if (!configured) {
          statusText = '未配置同步';
        } else if (lastTime == null) {
          statusText = '尚未同步';
        } else {
          statusText = '数据已同步';
        }

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      syncing
                          ? PhosphorIconsRegular.arrowsClockwise
                          : configured
                          ? PhosphorIconsRegular.cloudCheck
                          : PhosphorIconsRegular.cloudSlash,
                      size: 18,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimary,
                          ),
                        ),
                        if (lastTime != null)
                          Text(
                            l10n.lastSyncTime(
                              formatRelativeTime(lastTime, l10n),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Material(
                    type: MaterialType.transparency,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (configured) {
                          _triggerSync(vm, context);
                        } else {
                          showWebDavConfigDialog(context, vm);
                        }
                      },
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          configured ? '立即同步' : '去配置',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  // ==================== Sync Config Section ====================

  Widget _buildSyncConfigSection(
    ColorScheme cs,
    DataManagementViewModel vm,
    BuildContext context,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(label: '同步配置'),
            SettingsCard(
              showDividers: true,
              children: [
                SettingsNavigationTile(
                  iconWidget: const Icon(
                    PhosphorIconsRegular.cloud,
                    size: 16,
                    color: Color(0xFF5C6BC0),
                  ),
                  iconBackground: const Color(0xFFE8EAF6),
                  title: 'WebDAV 服务器',
                  subtitle: vm.serverUrl.value.isNotEmpty
                      ? vm.serverUrl.value
                      : '未配置',
                  onTap: () => showWebDavConfigDialog(context, vm),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }


  // ==================== Danger Zone ====================

  Widget _buildDangerZone(
    ColorScheme cs,
    DataManagementViewModel vm,
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return DangerSection(
          label: l10n.dangerZone,
          children: [
            DangerItem(
              icon: PhosphorIconsRegular.broom,
              title: l10n.clearAllData,
              description: l10n.clearAllDataDesc,
              onTap: () => _confirmClearCache(vm, context),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupSuccess)),
        );
      case BackupResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupFailed(vm.errorMessage.value ?? ''))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.restoreFailed(''))),
      );
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
            content: Text('${l10n.restoreSuccess}。${l10n.restoreRestartNotice}'),
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case RestoreResult.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.restoreFailed(vm.errorMessage.value ?? ''))),
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

  void _confirmClearCache(DataManagementViewModel vm, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showConfirmActionDialog(
      context,
      title: l10n.clearAllDataTitle,
      content: l10n.clearAllDataContent,
      confirmLabel: l10n.confirmClear,
      onConfirm: () async {
        vm.loading.value = true;
        try {
          await vm.clearCache();
          if (!context.mounted) return;
          showInfoSnack(context, l10n.dataCleared);
        } catch (e) {
          if (!context.mounted) return;
          showInfoSnack(context, l10n.dataClearFailed(e.toString()));
        } finally {
          vm.loading.value = false;
        }
      },
    );
  }

  // ==================== Sync Action ====================

  Future<void> _triggerSync(
    DataManagementViewModel vm,
    BuildContext context,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await vm.triggerSync();
    if (!context.mounted) return;
    if (result == null) {
      showInfoSnack(context, l10n.syncConfigInvalid);
      return;
    }
    showInfoSnack(
      context,
      result.success
          ? l10n.syncSuccess
          : '${l10n.syncFailed}：${result.error ?? l10n.unknownError}',
    );
  }
}
