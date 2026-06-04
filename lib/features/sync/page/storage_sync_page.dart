import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/features/sync/application/storage_sync_view_model.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/features/sync/page/widgets/webdav_config_dialog.dart';

class StorageSyncPage extends HookWidget {
  const StorageSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => StorageSyncViewModel());

    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '存储与同步',
          style: TextStyle(
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
    StorageSyncViewModel vm,
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
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      syncing
                          ? PhosphorIconsRegular.arrowsClockwise
                          : configured
                          ? PhosphorIconsRegular.cloudCheck
                          : PhosphorIconsRegular.cloudSlash,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (lastTime != null)
                          Text(
                            l10n.lastSyncTime(
                              formatRelativeTime(lastTime, l10n),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (configured) {
                        _triggerSync(vm, context);
                      } else {
                        showWebDavConfigDialog(context, vm);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        configured ? '立即同步' : '去配置',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    StorageSyncViewModel vm,
    BuildContext context,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '同步配置', colorScheme: cs),
            SettingsCard(
              colorScheme: cs,
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

  // ==================== Data Management Section ====================

  // ==================== Danger Zone ====================

  Widget _buildDangerZone(
    ColorScheme cs,
    StorageSyncViewModel vm,
    BuildContext context,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '危险操作',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.error.withValues(alpha: 0.8),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.error.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: InkWell(
                onTap: () => _confirmReset(cs, vm, context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          PhosphorIconsRegular.lightning,
                          size: 16,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '重置所有本地数据',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cs.error,
                              ),
                            ),
                            Text(
                              '清除全部书籍、笔记、生词本与设置',
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Dialogs ====================

  void _confirmReset(
    ColorScheme cs,
    StorageSyncViewModel vm,
    BuildContext context,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(PhosphorIconsRegular.warning, size: 20, color: cs.error),
            const SizedBox(width: 8),
            const Text('确认重置', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('此操作将清除全部书籍、笔记、生词本、阅读进度与应用设置。\n\n此操作不可撤销，请慎重。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showFinalConfirm(cs, context);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirm(ColorScheme cs, BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('二次确认'),
        content: const Text('请输入 RESET 以确认操作：'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  // ==================== Sync Action ====================

  Future<void> _triggerSync(
    StorageSyncViewModel vm,
    BuildContext context,
  ) async {
    final result = await vm.triggerSync();
    if (!context.mounted) return;
    if (result == null) {
      showInfoSnack(context, '同步配置无效，请检查 WebDAV 设置');
      return;
    }
    showInfoSnack(
      context,
      result.success ? '同步成功' : '同步失败：${result.error ?? "未知错误"}',
    );
  }
}
