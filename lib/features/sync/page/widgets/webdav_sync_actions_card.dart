import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/features/sync/application/services/sync_models.dart';
import 'package:zephyr_reader/features/sync/application/webdav_settings_view_model.dart';
import 'package:zephyr_reader/features/sync/page/widgets/webdav_conflicts_dialog.dart';

class WebDavSyncActionsCard extends HookWidget {
  final WebDavSettingsViewModel vm;

  const WebDavSyncActionsCard({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final isSyncing = useSignalValue<bool, Signal<bool>>(vm.isSyncing);
    final syncMessage = useSignalValue<String, Signal<String>>(vm.syncMessage);
    final syncProgress = useSignalValue<double, Signal<double>>(
      vm.syncProgress,
    );
    final conflicts =
        useSignalValue<List<ConflictInfo>, Signal<List<ConflictInfo>>>(
          vm.conflicts,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '同步操作',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isSyncing) ...[
              LinearProgressIndicator(value: syncProgress),
              const SizedBox(height: 8),
              Center(child: Text(syncMessage)),
              const SizedBox(height: 16),
            ],
            if (conflicts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsFill.warning,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '存在 ${conflicts.length} 个冲突需要解决',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => showWebDavConflictsDialog(
                        context,
                        vm.syncService,
                        conflicts,
                      ),
                      child: const Text('查看'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            ListTile(
              leading: const Icon(PhosphorIconsRegular.cloudArrowUp),
              title: const Text('立即上传'),
              subtitle: const Text('将本地数据上传到服务器'),
              onTap: isSyncing
                  ? null
                  : () => vm.performSync(SyncDirection.upload),
              enabled: !isSyncing,
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.cloudArrowDown),
              title: const Text('立即下载'),
              subtitle: const Text('从服务器下载数据到本地'),
              onTap: isSyncing
                  ? null
                  : () => vm.performSync(SyncDirection.download),
              enabled: !isSyncing,
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.arrowsClockwise),
              title: const Text('双向同步'),
              subtitle: const Text('同步本地和服务器的数据'),
              onTap: isSyncing
                  ? null
                  : () => vm.performSync(SyncDirection.both),
              enabled: !isSyncing,
            ),
          ],
        ),
      ),
    );
  }
}
