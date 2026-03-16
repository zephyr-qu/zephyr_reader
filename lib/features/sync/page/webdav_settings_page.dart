/// WebDAV 同步设置页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/services/webdav_config_service.dart';
import '../application/services/webdav_sync_service.dart';

/// WebDAV 同步设置页面
class WebDavSettingsPage extends HookWidget {
  const WebDavSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = useMemoized(
      () => WebDavConfigService(prefs: GetIt.I<SharedPreferences>()),
    );
    final syncService = useMemoized(() => WebDavSyncService());
    final isConfigured = useState(false);
    final isTesting = useState(false);
    final testResult = useState<bool?>(null);
    final lastSyncTime = useState<DateTime?>(null);
    final syncStatus = useState('未配�?');

    // 加载配置状�?
       useEffect(() {
      _loadConfigStatus(configService, isConfigured, lastSyncTime, syncStatus);
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConfigStatus(
              configService,
              isConfigured,
              lastSyncTime,
              syncStatus,
            ),
            tooltip: '刷新状�?',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 同步状�?
            _buildSyncStatusCard(context, lastSyncTime.value, syncStatus.value),
          const SizedBox(height: 24),
          // WebDAV 配置
          _buildWebDavConfigCard(
            context,
            configService,
            isConfigured.value,
            isTesting,
            testResult,
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
    ValueNotifier<bool> isConfigured,
    ValueNotifier<DateTime?> lastSyncTime,
    ValueNotifier<String> syncStatus,
  ) async {
    final config = await configService.getConfig();
    isConfigured.value = config != null;
    lastSyncTime.value = await configService.getLastSyncTime();
    syncStatus.value = isConfigured.value ? '已配�? : '未配�?;
  }

  Widget _buildSyncStatusCard(
    BuildContext context,
    DateTime? lastSyncTime,
    String syncStatus,
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
                  Icons.cloud_sync,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Text(
                  '同步状�?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '最后同步时间：${lastSyncTime != null ? _formatDateTime(lastSyncTime) : "从未同步"}',
            ),
            const SizedBox(height: 8),
            Text('同步状态：$syncStatus'),
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
      return '${difference.inMinutes}分钟�?';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时�?';
    } else {
      return '${dateTime.month}-${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildWebDavConfigCard(
    BuildContext context,
    WebDavConfigService configService,
    bool isConfigured,
    ValueNotifier<bool> isTesting,
    ValueNotifier<bool?> testResult,
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
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('已配�?WebDAV 服务�?'),
                subtitle: Text('点击修改配置'),
              ),
            ] else ...[
              const ListTile(
                leading: Icon(Icons.cloud_off, color: Colors.grey),
                title: Text('未配�?WebDAV 服务�?'),
                subtitle: Text('点击配置以启用同�?'),
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
                      icon: const Icon(Icons.add),
                      label: const Text('配置 WebDAV'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showConfigDialog(context, configService),
                      icon: const Icon(Icons.edit),
                      label: const Text('修改配置'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _testConnection(
                      context,
                      configService,
                      isTesting,
                      testResult,
                    ),
                    icon: isTesting.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi),
                    label: Text(
                      testResult.value == null
                          ? '测试连接'
                          : testResult.value!
                          ? '连接成功'
                          : '连接失败',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: testResult.value == null
                          ? null
                          : testResult.value!
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
    ValueNotifier<bool> isTesting,
    ValueNotifier<bool?> testResult,
  ) async {
    isTesting.value = true;
    testResult.value = null;

    try {
      final result = await configService.testCurrentConfig();
      testResult.value = result;

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? 'WebDAV 连接测试成功' : 'WebDAV 连接测试失败，请检查配�?'),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      testResult.value = false;

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('连接异常�?e'), backgroundColor: Colors.red),
      );
    } finally {
      isTesting.value = false;
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
    final selectedPreset = useState<WebDavPreset?>(null);

    if (!context.mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                        selectedPreset.value?.name == preset.name;
                    return ChoiceChip(
                      label: Text(preset.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          selectedPreset.value = preset;
                          if (preset.baseUrl.isNotEmpty) {
                            serverController.text = preset.baseUrl;
                          }
                          remotePathController.text = preset.remotePath;
                        }
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
                    prefixIcon: Icon(Icons.cloud),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入服务器地址';
                    }
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return '请输入完整的 URL（包�?http:// �?https://�?';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户�?',
                    prefixIcon: Icon(Icons.person),
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
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密�?';
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
                    prefixIcon: Icon(Icons.folder),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入远程目�?';
                    }
                    if (!value.startsWith('/')) {
                      return '远程目录应以 / 开�?';
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
                      content: Text('配置已清�?'),
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
            content: Text('WebDAV 配置已保�?'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存配置失败�?e'), backgroundColor: Colors.red),
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
    final autoSyncEnabled = useState(configService.autoSyncEnabled.value);
    final syncInterval = useState(configService.autoSyncInterval.value);

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
              subtitle: const Text('定期自动同步数据到云�?'),
              value: autoSyncEnabled.value,
              onChanged: (value) async {
                autoSyncEnabled.value = value;
                configService.autoSyncEnabled.value = value;
                await configService.setAutoSync(enabled: value);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value ? '自动同步已启�?' : '自动同步已禁�?'),
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
    WebDavSyncService syncService,
    WebDavConfigService configService,
  ) {
    final isSyncing = useState(false);
    final syncMessage = useState('');
    final syncProgress = useState(0.0);

    Future<void> performSync(SyncDirection direction) async {
      final config = await configService.getConfig();
      if (config == null) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先配置 WebDAV 服务�?'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      syncService.setConfig(config);
      isSyncing.value = true;
      syncMessage.value = '准备同步...';
      syncProgress.value = 0.0;

      try {
        final result = await syncService.syncAll(direction: direction);

        if (!context.mounted) return;

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '同步完成！上传：${result.uploadedCount}, 下载�?{result.downloadedCount}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.conflictCount > 0
                    ? '同步完成，但存在 ${result.conflictCount} 个冲�?'
                    : '同步失败�?{result.error ?? "未知错误"}',
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
          SnackBar(content: Text('同步异常�?e'), backgroundColor: Colors.red),
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
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('立即上传'),
              subtitle: const Text('将本地数据上传到服务�?'),
              onTap: isSyncing.value
                  ? null
                  : () => performSync(SyncDirection.upload),
              enabled: !isSyncing.value,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('立即下载'),
              subtitle: const Text('从服务器下载数据到本�?'),
              onTap: isSyncing.value
                  ? null
                  : () => performSync(SyncDirection.download),
              enabled: !isSyncing.value,
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('双向同步'),
              subtitle: const Text('同步本地和服务器的数�?'),
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
            const Text('支持�?WebDAV 服务�?'),
            const SizedBox(height: 8),
            const Text('�?坚果�?'),
            const Text('�?Nextcloud'),
            const Text('�?ownCloud'),
            const Text('�?Seafile'),
            const Text('�?其他标准 WebDAV 服务'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebDAV 同步帮助'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '什么是 WebDAV 同步�?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('WebDAV 同步功能可以将您的阅读进度、书签、书架等数据同步到云端存储，实现多设备间的数据同步�?'),
              const SizedBox(height: 16),
              const Text(
                '如何配置�?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. 选择一�?WebDAV 服务提供商（如坚果云�?'),
              const Text('2. 获取 WebDAV 服务器地址、用户名和密�?'),
              const Text('3. 在配置页面填写相关信�?'),
              const Text('4. 点击"测试连接"验证配置'),
              const SizedBox(height: 16),
              const Text('同步说明', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('�?上传：将本地数据上传到服务器'),
              const Text('�?下载：从服务器下载数据到本地'),
              const Text('�?双向同步：自动处理冲突，保持数据一�?'),
              const SizedBox(height: 16),
              const Text(
                '注意事项',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '�?首次使用建议先上传本地数�?',
                style: TextStyle(color: Colors.red),
              ),
              const Text('�?同步前请确保网络连接稳定', style: TextStyle(color: Colors.red)),
              const Text(
                '�?如遇冲突，系统会自动处理，但建议定期检查同步状�?',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道�?'),
          ),
        ],
      ),
    );
  }
}
