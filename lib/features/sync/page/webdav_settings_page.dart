/// WebDAV 同步设置页面
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';

import '../application/services/webdav_sync_service.dart';
import '../application/sync_view_model.dart';
import 'conflict_resolution_page.dart';

/// WebDAV 同步设置页面
class WebDavSettingsPage extends HookWidget {
  const WebDavSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = useMemoized(
      () => WebDavConfigService(prefs: GetIt.I<SharedPreferences>()),
    );
    final syncService = useMemoized(() => EnhancedWebDavSyncService());
    final syncVm = useMemoized(() => getIt<SyncViewModel>());
    final isConfigured = useSignal(false);
    final isTesting = useSignal(false);
    final testResult = useSignal<bool?>(null);
    final lastSyncTime = useSignal<DateTime?>(null);
    final syncStatus = useSignal('未配置');

    useEffect(() {
      _loadConfigStatus(
        configService,
        (v) => isConfigured.value = v,
        (v) => lastSyncTime.value = v,
        (v) => syncStatus.value = v,
      );
      syncVm.loadPendingTasks();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => _loadConfigStatus(
              configService,
              (v) => isConfigured.value = v,
              (v) => lastSyncTime.value = v,
              (v) => syncStatus.value = v,
            ),
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 同步状态
          _buildSyncStatusCard(
            context,
            lastSyncTime.value,
            syncStatus.value,
            isConfigured.value,
            isTesting.value,
            testResult.value,
          ),
          const SizedBox(height: 24),
          // WebDAV 配置
          _buildWebDavConfigCard(
            context,
            configService,
            isConfigured.value,
            isTesting.value,
            testResult.value,
            () => _testConnection(
              context,
              configService,
              (v) => testResult.value = v,
              (v) => isTesting.value = v,
            ),
          ),
          const SizedBox(height: 24),
          // 自动同步设置
          _buildAutoSyncCard(context, configService),
          const SizedBox(height: 24),
          // 同步操作
          _buildSyncActionsCard(context, syncService, configService),
          const SizedBox(height: 24),
          // 帮助信息
          _buildHelpCard(context),
        ],
      ),
    );
  }

  Future<void> _loadConfigStatus(
    WebDavConfigService configService,
    ValueChanged<bool> onConfigChanged,
    ValueChanged<DateTime?> onTimeChanged,
    ValueChanged<String> onStatusChanged,
  ) async {
    final config = await configService.getConfig();
    onConfigChanged(config != null);
    onTimeChanged(await configService.getLastSyncTime());
    onStatusChanged(config != null ? '已配置' : '未配置');
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    DateTime? lastSyncTime,
    String syncStatus,
    bool isConfigured,
    bool isTesting,
    bool? testResult,
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
                _ConnectionStatusDot(
                  isConfigured: isConfigured,
                  isTesting: isTesting,
                  testResult: testResult,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '最后同步时间：${lastSyncTime != null ? _formatDateTime(lastSyncTime) : "从未同步"}',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时';
    } else {
      return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildWebDavConfigCard(
    BuildContext context,
    WebDavConfigService configService,
    bool isConfigured,
    bool isTesting,
    bool? testResult,
    VoidCallback onTestConnection,
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
                      onPressed: () =>
                          _showConfigDialog(context, configService),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('配置 WebDAV'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showConfigDialog(context, configService),
                      icon: const Icon(PhosphorIconsRegular.pencilSimple),
                      label: const Text('修改配置'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTestConnection,
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
    WebDavConfigService configService,
    ValueChanged<bool?> onTestResult,
    ValueChanged<bool> onTestingChanged,
  ) async {
    onTestingChanged(true);
    onTestResult(null);

    try {
      final result = await configService.testCurrentConfig();
      onTestResult(result);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'WebDAV 连接测试成功' : 'WebDAV 连接测试失败，请检查配置'),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      onTestResult(false);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接异常：$e'), backgroundColor: Colors.red),
      );
    } finally {
      onTestingChanged(false);
    }
  }

  void _showConfigDialog(
    BuildContext context,
    WebDavConfigService configService,
  ) async {
    final config = await configService.getConfig();

    final serverController = TextEditingController(text: config?.baseUrl ?? '');
    final usernameController = TextEditingController(
      text: config?.username ?? '',
    );
    final passwordController = TextEditingController(
      text: config?.password ?? '',
    );
    final remotePathController = TextEditingController(
      text: config?.remotePath ?? '/zephyr_reader',
    );
    var selectedPreset = null as WebDavPreset?;

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('配置 WebDAV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择预设',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: WebDavConfigService.getPresets().map((preset) {
                    final isSelected =
                        selectedPreset?.name == preset.name;
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedPreset = preset;
                            if (preset.baseUrl.isNotEmpty) {
                              serverController.text = preset.baseUrl;
                            }
                            remotePathController.text = preset.remotePath;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: serverController,
                  decoration: const InputDecoration(
                    labelText: '服务器地址',
                    hintText: 'https://dav.jianguoyun.com/dav',
                    prefixIcon: Icon(PhosphorIconsRegular.cloud),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入服务器地址';
                    }
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return '请输入完整的 URL（包含 http:// 或 https://）';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户',
                    prefixIcon: Icon(PhosphorIconsRegular.user),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(PhosphorIconsRegular.lockSimple),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: remotePathController,
                  decoration: const InputDecoration(
                    labelText: '远程目录',
                    hintText: '/zephyr_reader',
                    prefixIcon: Icon(PhosphorIconsRegular.folder),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入远程目录';
                    }
                    if (!value.startsWith('/')) {
                      return '远程目录应以 / 开头';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            if (config != null)
              TextButton(
                onPressed: () async {
                  await configService.clearConfig();
                  if (!context.mounted) return;
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('配置已清除'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('清除配置'),
              ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      // 验证表单
      final serverValid =
          serverController.text.isNotEmpty &&
          (serverController.text.startsWith('http://') ||
              serverController.text.startsWith('https://'));
      final usernameValid = usernameController.text.isNotEmpty;
      final passwordValid = passwordController.text.isNotEmpty;
      final remotePathValid =
          remotePathController.text.isNotEmpty &&
          remotePathController.text.startsWith('/');

      if (!serverValid ||
          !usernameValid ||
          !passwordValid ||
          !remotePathValid) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请填写完整的配置信息'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 保存配置
      try {
        await configService.saveConfig(
          WebDavConfig(
            baseUrl: serverController.text,
            username: usernameController.text,
            password: passwordController.text,
            remotePath: remotePathController.text,
          ),
        );

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WebDAV 配置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存配置失败'), backgroundColor: Colors.red),
        );
      }
    }

    serverController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    remotePathController.dispose();
  }

  Widget _buildAutoSyncCard(
    BuildContext context,
    WebDavConfigService configService,
  ) {
    final autoSyncEnabled = useSignal(configService.autoSyncEnabled.value);
    final syncInterval = useSignal(configService.autoSyncInterval.value);

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
              value: autoSyncEnabled.value,
              onChanged: (value) async {
                autoSyncEnabled.value = value;
                configService.autoSyncEnabled.value = value;
                await configService.setAutoSync(enabled: value);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? '自动同步已启用' : '自动同步已禁用'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
            if (autoSyncEnabled.value) ...[
              const SizedBox(height: 16),
              const Text('同步间隔'),
              Slider(
                value: syncInterval.value.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                label: '${syncInterval.value}分钟',
                onChanged: (value) async {
                  syncInterval.value = value.toInt();
                  configService.autoSyncInterval.value = value.toInt();
                  await configService.setAutoSync(
                    enabled: true,
                    intervalMinutes: value.toInt(),
                  );
                },
              ),
              Center(child: Text('${syncInterval.value} 分钟')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncActionsCard(
    BuildContext context,
    EnhancedWebDavSyncService syncService,
    WebDavConfigService configService,
  ) {
    final isSyncing = useSignal(false);
    final syncMessage = useSignal('');
    final syncProgress = useSignal(0.0);
    final conflicts = <ConflictInfo>[];

    Future<void> performSync(SyncDirection direction) async {
      final config = await configService.getConfig();
      if (config == null) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先配置 WebDAV 服务'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      syncService.setConfig(config);
      isSyncing.value = true;
      syncMessage.value = '准备同步...';
      syncProgress.value = 0.0;
      conflicts.clear();

      try {
        // 监听同步事件
        final subscription = syncService.eventStream.listen((event) {
          syncMessage.value = event.message;
          if (event.progress != null && event.total != null) {
            syncProgress.value = event.progress! / event.total!;
          }

          // 处理冲突事件
          if (event.type == SyncEventType.conflict &&
              event.conflictInfo != null) {
            conflicts.add(event.conflictInfo!);
          }
        });

        final result = await syncService.syncAll(
          direction: direction,
          autoResolveConflicts: true,
        );

        await subscription.cancel();

        if (!context.mounted) return;

        // 如果有冲突需要解决
        if (conflicts.isNotEmpty) {
          _showConflictsDialog(context, syncService, conflicts.toList());
          return;
        }

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '同步完成！上传：${result.uploadedCount}, 下载：${result.downloadedCount}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.conflictCount > 0
                    ? '同步完成，但存在 ${result.conflictCount} 个冲突'
                    : '同步失败：${result.error ?? "未知错误"}',
              ),
              backgroundColor: result.conflictCount > 0
                  ? Colors.orange
                  : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步异常：$e'), backgroundColor: Colors.red),
        );
      } finally {
        isSyncing.value = false;
        syncMessage.value = '';
        syncProgress.value = 0.0;
      }
    }

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
            if (isSyncing.value) ...[
              LinearProgressIndicator(value: syncProgress.value),
              const SizedBox(height: 8),
              Center(child: Text(syncMessage.value)),
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
                      onPressed: () =>
                          _showConflictsDialog(context, syncService, conflicts),
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
              onTap: isSyncing.value
                  ? null
                  : () => performSync(SyncDirection.upload),
              enabled: !isSyncing.value,
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.cloudArrowDown),
              title: const Text('立即下载'),
              subtitle: const Text('从服务器下载数据到本地'),
              onTap: isSyncing.value
                  ? null
                  : () => performSync(SyncDirection.download),
              enabled: !isSyncing.value,
            ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.arrowsClockwise),
              title: const Text('双向同步'),
              subtitle: const Text('同步本地和服务器的数据'),
              onTap: isSyncing.value
                  ? null
                  : () => performSync(SyncDirection.both),
              enabled: !isSyncing.value,
            ),
          ],
        ),
      ),
    );
  }

  /// 显示冲突对话框
  void _showConflictsDialog(
    BuildContext context,
    EnhancedWebDavSyncService syncService,
    List<ConflictInfo> conflicts,
  ) async {
    final result = await showDialog<List<ConflictInfo>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(PhosphorIconsFill.warning, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text('需要同步冲突 (${conflicts.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    PhosphorIconsFill.warning,
                    color: Colors.orange.shade700,
                  ),
                  title: Text(_getDataTypeName(conflict.dataType)),
                  subtitle: Text(conflict.description),
                  trailing: conflict.autoResolution != null
                      ? Chip(
                          label: Text(
                            _getResolutionName(conflict.autoResolution!),
                          ),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后处理'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(conflicts),
            child: const Text('解决冲突'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // 打开冲突解决页面
      for (final conflict in result) {
        if (!context.mounted) break;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => ConflictResolutionPage(
              syncService: syncService,
              conflictInfo: conflict,
            ),
          ),
        );
      }
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
        return '使用本地';
      case ConflictResolution.useRemote:
        return '使用远程';
      case ConflictResolution.merge:
        return '合并';
    }
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
              onPressed: () => _showHelpDialog(context),
              child: const Text('查看帮助文档'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebDAV 同步帮助'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '什么是 WebDAV 同步',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('WebDAV 同步功能可以将您的阅读进度、书签、书架等数据同步到云端存储，实现多设备间的数据同步'),
              SizedBox(height: 16),
              Text('如何配置', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. 选择一个 WebDAV 服务提供商（如坚果云）'),
              Text('2. 获取 WebDAV 服务器地址、用户名和密码'),
              Text('3. 在配置页面填写相关信息'),
              Text('4. 点击"测试连接"验证配置'),
              SizedBox(height: 16),
              Text('同步说明', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('上传：将本地数据上传到服务器'),
              Text('下载：从服务器下载数据到本地'),
              Text('双向同步：自动处理冲突，保持数据一致'),
              SizedBox(height: 16),
              Text(
                '注意事项',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text('首次使用建议先上传本地数据', style: TextStyle(color: Colors.red)),
              Text('同步前请确保网络连接稳定', style: TextStyle(color: Colors.red)),
              Text(
                '如遇冲突，系统会自动处理，但建议定期检查同步状态',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusDot extends StatefulWidget {
  final bool isConfigured;
  final bool isTesting;
  final bool? testResult;

  const _ConnectionStatusDot({
    required this.isConfigured,
    required this.isTesting,
    required this.testResult,
  });

  @override
  State<_ConnectionStatusDot> createState() => _ConnectionStatusDotState();
}

class _ConnectionStatusDotState extends State<_ConnectionStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isTesting) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_ConnectionStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTesting && !oldWidget.isTesting) {
      _controller.repeat(reverse: true);
    } else if (!widget.isTesting && oldWidget.isTesting) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    bool pulse;
    String tooltip;

    if (widget.isTesting) {
      color = Colors.amber;
      pulse = true;
      tooltip = '连接测试中…';
    } else if (widget.testResult == true) {
      color = Colors.green;
      pulse = false;
      tooltip = '连接正常';
    } else if (widget.testResult == false) {
      color = Colors.red;
      pulse = false;
      tooltip = '连接失败';
    } else if (widget.isConfigured) {
      color = theme.colorScheme.secondary;
      pulse = false;
      tooltip = '已配置（未测试）';
    } else {
      color = Colors.grey;
      pulse = false;
      tooltip = '未配置';
    }

    return Tooltip(
      message: tooltip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = pulse
              ? (0.4 + 0.6 * (1 - math.cos(_controller.value * math.pi)) / 2)
              : 1.0;
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              boxShadow: pulse
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6 * opacity),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }
}
