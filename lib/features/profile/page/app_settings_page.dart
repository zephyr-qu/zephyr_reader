/// 应用设置页面
///
/// 提供应用级别的设置选项：
/// - 主题设置
/// - 语言设置
/// - 通知设置
/// - 存储管理
/// - 备份与恢复
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/cache/cache_manager.dart';
import 'package:zephyr_reader/features/profile/page/widgets/backup_dialog.dart';
import 'package:zephyr_reader/features/sync/application/services/backup_restore_service.dart';

/// 应用设置页面
class AppSettingsPage extends StatefulHookWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> with SignalsMixin {
  final cacheSize = useSignal<String>('计算中...');
  final isClearing = useSignal(false);

  final backupRestoreService = useMemoized(() => BackupRestoreService());
  final isBackingUp = useSignal(false);
  final isRestoring = useSignal(false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    try {
      final bytes = await CacheManager.getCacheSize();
      cacheSize.value = CacheManager.formatCacheSize(bytes);
    } catch (e) {
      cacheSize.value = '未知';
    }
  }

  Future<void> _clearCache() async {
    isClearing.value = true;
    try {
      final bytes = await CacheManager.clearCache();
      final sizeText = CacheManager.formatCacheSize(bytes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清理 $sizeText 缓存'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      await _loadCacheSize();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('清理缓存失败'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isClearing.value = false;
    }
  }

  Future<void> _createBackup() async {
    // 显示备份对话框
    final selectedTypes = await _showBackupTypeDialog();
    if (selectedTypes == null || selectedTypes.isEmpty) return;

    isBackingUp.value = true;
    try {
      final backupInfo = await backupRestoreService.createBackup(
        types: selectedTypes,
      );

      if (mounted) {
        if (backupInfo != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('备份创建成功：${backupInfo.fileSizeFormatted}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('备份创建失败'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份创建失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isBackingUp.value = false;
    }
  }

  Future<void> _restoreBackup() async {
    // 显示备份列表
    final backups = backupRestoreService.backups.value;
    if (backups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无备份记录')));
      }
      return;
    }

    final selectedBackup = await showRestoreBackupDialog(context, backups);
    if (selectedBackup == null) return;

    // 确认恢复
    final confirmed = await showRestoreConfirmDialog(context, selectedBackup);
    if (!confirmed) return;

    isRestoring.value = true;
    try {
      final success = await backupRestoreService.restoreBackup(
        selectedBackup.id,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('数据恢复成功'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('数据恢复失败'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据恢复失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      isRestoring.value = false;
    }
  }

  Future<List<BackupType>?> _showBackupTypeDialog() async {
    final selectedTypes = <BackupType>[BackupType.all];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('选择备份内容'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...BackupType.values.map((type) {
                  final isSelected = selectedTypes.contains(type);
                  return CheckboxListTile(
                    title: Text(_getBackupTypeName(type)),
                    value: isSelected,
                    onChanged: (value) {
                      if (value == true) {
                        if (type == BackupType.all) {
                          selectedTypes.clear();
                          selectedTypes.add(BackupType.all);
                        } else {
                          selectedTypes.remove(BackupType.all);
                          if (!selectedTypes.contains(type)) {
                            selectedTypes.add(type);
                          }
                        }
                      } else {
                        selectedTypes.remove(type);
                        if (selectedTypes.isEmpty) {
                          selectedTypes.add(BackupType.all);
                        }
                      }
                      setDialogState(() {});
                    },
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      return selectedTypes;
    }

    return null;
  }

  String _getBackupTypeName(BackupType type) {
    switch (type) {
      case BackupType.all:
        return '全部数据';
      case BackupType.readingProgress:
        return '阅读进度';
      case BackupType.bookmarks:
        return '书签';
      case BackupType.bookshelf:
        return '书架';
      case BackupType.settings:
        return '设置';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 设置状态
    final themeMode = useSignal(0); // 0: 跟随系统，1: 浅色，2: 深色，3: 纯黑
    final language = useSignal(0); // 0: 跟随系统，1: 简体中文，2: English
    final autoSync = useSignal(false);
    final syncInterval = useSignal(0); // 0: 手动，1: 每天，2: 每周

    return Scaffold(
      appBar: AppBar(title: const Text('应用设置')),
      body: ListView(
        children: [
          // 主题设置
          _buildSection(
            context,
            title: '主题与外观',
            children: [
              _buildRadioSetting(
                context,
                title: '主题模式',
                value: themeMode.value,
                groupValue: themeMode.value,
                items: const [
                  ('跟随系统', 0),
                  ('浅色模式', 1),
                  ('深色模式', 2),
                  ('纯黑模式', 3),
                ],
                onChanged: (v) => themeMode.value = v ?? 0,
              ),
            ],
          ),

          // 语言设置
          _buildSection(
            context,
            title: '语言与地区',
            children: [
              _buildRadioSetting(
                context,
                title: '显示语言',
                value: language.value,
                groupValue: language.value,
                items: const [('跟随系统', 0), ('简体中文', 1), ('English', 2)],
                onChanged: (v) => language.value = v ?? 0,
              ),
              ListTile(
                title: const Text('地区'),
                subtitle: const Text('中国大陆'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final regions = [
                    {'code': 'CN', 'name': '中国大陆'},
                    {'code': 'HK', 'name': '中国香港'},
                    {'code': 'TW', 'name': '中国台湾'},
                    {'code': 'US', 'name': '美国'},
                    {'code': 'GB', 'name': '英国'},
                    {'code': 'JP', 'name': '日本'},
                    {'code': 'KR', 'name': '韩国'},
                    {'code': 'SG', 'name': '新加坡'},
                    {'code': 'MY', 'name': '马来西亚'},
                  ];

                  final selectedRegion = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('选择地区'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: regions.length,
                          itemBuilder: (context, index) {
                            final region = regions[index];
                            return ListTile(
                              title: Text(region['name']!),
                              onTap: () => Navigator.pop(context, region),
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ],
                    ),
                  );

                  if (selectedRegion != null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('地区已更改为：${selectedRegion['name']}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          // 同步设置
          _buildSection(
            context,
            title: '同步设置',
            children: [
              _buildSwitchSetting(
                context,
                title: '自动同步',
                subtitle: '定期同步阅读进度和书架',
                value: autoSync.value,
                onChanged: (v) => autoSync.value = v,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('同步频率'),
                subtitle: Text(['手动同步', '每天一次', '每周一次'][syncInterval.value]),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await showModalBottomSheet<int>(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.sync_disabled),
                            title: const Text('手动同步'),
                            onTap: () => Navigator.pop(context, 0),
                          ),
                          ListTile(
                            leading: const Icon(Icons.sync),
                            title: const Text('每天一次'),
                            onTap: () => Navigator.pop(context, 1),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: const Text('每周一次'),
                            onTap: () => Navigator.pop(context, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (result != null) {
                    syncInterval.value = result;
                  }
                },
              ),
            ],
          ),

          // 存储管理
          _buildSection(
            context,
            title: '存储管理',
            children: [
              ListTile(
                title: const Text('清理缓存'),
                subtitle: Text(cacheSize.value),
                leading: const Icon(Icons.cleaning_services),
                trailing: isClearing.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: isClearing.value ? null : _clearCache,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('书籍存储位置'),
                subtitle: const Text('内部存储/Documents/ZephyrReader/books'),
                leading: const Icon(Icons.folder),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  // 显示存储位置选择对话框
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('书籍存储位置'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('当前存储位置：'),
                          const SizedBox(height: 8),
                          const Text(
                            '/storage/emulated/0/Documents/ZephyrReader/books',
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '注意：更改存储位置需要重启应用才能生效。',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择新位置'),
                        ),
                      ],
                    ),
                  );

                  if (result == true) {
                    if (!mounted) return;

                    // 使用 file_picker 选择目录
                    try {
                      final directory = await FilePicker.platform
                          .getDirectoryPath();

                      if (directory != null && mounted) {
                        // 保存新的存储路径
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('storage_path', directory);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('存储位置已更改，请重启应用'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('选择失败：$e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
            ],
          ),

          // 备份与恢复
          _buildSection(
            context,
            title: '备份与恢复',
            children: [
              ListTile(
                title: const Text('备份数据'),
                subtitle: const Text('备份书架、阅读进度和设置'),
                leading: const Icon(Icons.backup),
                trailing: isBackingUp.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: isBackingUp.value ? null : _createBackup,
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('恢复数据'),
                subtitle: const Text('从备份文件恢复数据'),
                leading: const Icon(Icons.restore),
                trailing: isRestoring.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: isRestoring.value ? null : _restoreBackup,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildRadioSetting(
    BuildContext context, {
    required String title,
    required int value,
    required int groupValue,
    required List<(String, int)> items,
    required ValueChanged<int?> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        children: items.map((item) {
          return RadioGroup<int>(
            groupValue: groupValue,
            onChanged: (v) {
              onChanged(v);
            },
            child: RadioListTile<int>(
              title: Text(item.$1),
              value: item.$2,
              contentPadding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}
