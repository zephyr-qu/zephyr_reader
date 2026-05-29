import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import '../application/services/webdav_config_service.dart';
import '../application/services/webdav_sync_service.dart';
import '../application/sync_view_model.dart';
import '../application/webdav_settings_view_model.dart';
import 'widgets/webdav_config_dialog.dart';
import 'widgets/webdav_help_dialog.dart';
import 'widgets/webdav_status_dot.dart';
import 'widgets/webdav_sync_actions_card.dart';

class WebDavSettingsPage extends HookWidget {
  const WebDavSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = useMemoized(
      () => WebDavConfigService(prefs: GetIt.I<SharedPreferences>()),
    );
    final vm = useMemoized(
      () => WebDavSettingsViewModel(
        configService: configService,
        syncService: WebDavSyncService(),
        syncVm: getIt<SyncViewModel>(),
      ),
    );

    useEffect(() {
      vm.loadConfigStatus();
      vm.syncVm.loadPendingTasks();
      return null;
    }, []);

    final isConfigured = useSignalValue<bool, Signal<bool>>(vm.isConfigured);
    final isTesting = useSignalValue<bool, Signal<bool>>(vm.isTesting);
    final testResult = useSignalValue<bool?, Signal<bool?>>(vm.testResult);
    final lastSyncTime = useSignalValue<DateTime?, Signal<DateTime?>>(
      vm.lastSyncTime,
    );
    final syncStatusText = useSignalValue<String, Signal<String>>(
      vm.syncStatusText,
    );
    final autoSyncEnabled = useSignalValue<bool, Signal<bool>>(
      vm.autoSyncEnabled,
    );
    final autoSyncInterval = useSignalValue<int, Signal<int>>(
      vm.autoSyncInterval,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => vm.loadConfigStatus(),
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSyncStatusCard(
            context,
            isConfigured,
            isTesting,
            testResult,
            lastSyncTime,
            syncStatusText,
          ),
          const SizedBox(height: 24),
          _buildWebDavConfigCard(
            context,
            isConfigured,
            isTesting,
            testResult,
            vm,
          ),
          const SizedBox(height: 24),
          _buildAutoSyncCard(context, vm, autoSyncEnabled, autoSyncInterval),
          const SizedBox(height: 24),
          WebDavSyncActionsCard(vm: vm),
          const SizedBox(height: 24),
          _buildHelpCard(context),
        ],
      ),
    );
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    bool isConfigured,
    bool isTesting,
    bool? testResult,
    DateTime? lastSyncTime,
    String syncStatusText,
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
                  PhosphorIconsRegular.cloudCheck,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  '同步状态',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                WebDavStatusDot(
                  isConfigured: isConfigured,
                  isTesting: isTesting,
                  testResult: testResult,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '最后同步时间：${lastSyncTime != null ? formatRelativeTime(lastSyncTime) : "从未同步"}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDavConfigCard(
    BuildContext context,
    bool isConfigured,
    bool isTesting,
    bool? testResult,
    WebDavSettingsViewModel vm,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WebDAV 配置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isConfigured) ...[
              const ListTile(
                leading: Icon(
                  PhosphorIconsFill.checkCircle,
                  color: Colors.green,
                ),
                title: Text('已配置 WebDAV 服务'),
                subtitle: Text('点击修改配置'),
              ),
            ] else ...[
              const ListTile(
                leading: Icon(
                  PhosphorIconsRegular.cloudSlash,
                  color: Colors.grey,
                ),
                title: Text('未配置 WebDAV 服务'),
                subtitle: Text('点击配置以启用同步'),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isConfigured)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showWebDavConfigDialog(context, vm),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('配置 WebDAV'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showWebDavConfigDialog(context, vm),
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                      label: const Text('修改配置'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isTesting
                        ? null
                        : () => _testConnection(context, vm),
                    icon: isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(PhosphorIconsRegular.wifiHigh),
                    label: Text(
                      testResult == null
                          ? '测试连接'
                          : testResult
                          ? '连接成功'
                          : '连接失败',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: testResult == null
                          ? null
                          : testResult
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testConnection(
    BuildContext context,
    WebDavSettingsViewModel vm,
  ) async {
    final result = await vm.testConnection();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result ? 'WebDAV 连接测试成功' : 'WebDAV 连接测试失败，请检查配置'),
        backgroundColor: result ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildAutoSyncCard(
    BuildContext context,
    WebDavSettingsViewModel vm,
    bool autoSyncEnabled,
    int autoSyncInterval,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自动同步',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('启用自动同步'),
              subtitle: const Text('定期自动同步数据到云端'),
              value: autoSyncEnabled,
              onChanged: (value) async {
                await vm.toggleAutoSync(value);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? '自动同步已启用' : '自动同步已禁用'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            if (autoSyncEnabled) ...[
              const SizedBox(height: 16),
              const Text('同步间隔'),
              Slider(
                value: autoSyncInterval.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                label: '$autoSyncInterval分钟',
                onChanged: (value) async {
                  await vm.setAutoSyncInterval(value.toInt());
                },
              ),
              Center(child: Text('$autoSyncInterval 分钟')),
            ],
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
              '帮助',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('支持 WebDAV 服务'),
            const SizedBox(height: 8),
            const Text('坚果云'),
            const Text('Nextcloud'),
            const Text('ownCloud'),
            const Text('Seafile'),
            const Text('其他标准 WebDAV 服务'),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => showWebDavHelpDialog(context),
              child: const Text('查看帮助文档'),
            ),
          ],
        ),
      ),
    );
  }
}
