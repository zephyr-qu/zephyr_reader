/// 应用设置页面 - 现代化设计
///
/// 提供应用级别的设置选项：
/// - 主题设置
/// - 语言设置
/// - 通知设置
/// - 存储管理
/// - 备份与恢复
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/utils/cache_utils.dart';
import 'package:zephyr_reader/features/profile/page/widgets/backup_dialog.dart';
import 'package:zephyr_reader/features/sync/application/services/backup_restore_service.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';

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
      final bytes = await CacheUtils.getCacheSize();
      cacheSize.value = CacheUtils.formatCacheSize(bytes);
    } catch (e) {
      cacheSize.value = '未知';
    }
  }

  Future<void> _clearCache() async {
    isClearing.value = true;
    try {
      final bytes = await CacheUtils.clearCache();
      final sizeText = CacheUtils.formatCacheSize(bytes);

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
    final theme = Theme.of(context);
    final pagePadding = LayoutBreakpoints.getPagePadding(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar
          const SliverAppBar(
            floating: true,
            title: Text('应用设置'),
            elevation: 0,
            scrolledUnderElevation: 2,
          ),

          SliverPadding(
            padding: pagePadding,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 主题设置
                  _buildSectionCard(
                    context,
                    icon: Icons.palette_rounded,
                    title: '主题与外观',
                    children: [_buildThemeSelector(context, themeMode)],
                  ),
                  const SizedBox(height: 16),

                  // 语言设置
                  _buildSectionCard(
                    context,
                    icon: Icons.language_rounded,
                    title: '语言与地区',
                    children: [
                      _buildLanguageSelector(context, language),
                      _buildDivider(),
                      _buildRegionSelector(context),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 同步设置
                  _buildSectionCard(
                    context,
                    icon: Icons.sync_rounded,
                    title: '同步设置',
                    children: [
                      _buildSwitchSetting(
                        context,
                        icon: Icons.auto_awesome_rounded,
                        title: '自动同步',
                        subtitle: '定期同步阅读进度和书架',
                        value: autoSync.value,
                        onChanged: (v) => autoSync.value = v,
                      ),
                      _buildDivider(),
                      _buildSyncFrequencySelector(context, syncInterval),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 存储管理
                  _buildSectionCard(
                    context,
                    icon: Icons.storage_rounded,
                    title: '存储管理',
                    children: [
                      _buildCacheCleaner(context),
                      _buildDivider(),
                      _buildStorageLocationSelector(context),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 备份与恢复
                  _buildSectionCard(
                    context,
                    icon: Icons.backup_rounded,
                    title: '备份与恢复',
                    children: [
                      _buildBackupItem(
                        context,
                        icon: Icons.cloud_upload_rounded,
                        iconColor: theme.colorScheme.primary,
                        title: '备份数据',
                        subtitle: '备份书架、阅读进度和设置',
                        isLoading: isBackingUp.value,
                        onTap: _createBackup,
                      ),
                      _buildDivider(),
                      _buildBackupItem(
                        context,
                        icon: Icons.cloud_download_rounded,
                        iconColor: theme.colorScheme.secondary,
                        title: '恢复数据',
                        subtitle: '从备份文件恢复数据',
                        isLoading: isRestoring.value,
                        onTap: _restoreBackup,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1);
  }

  Widget _buildThemeSelector(BuildContext context, Signal<int> themeMode) {
    final theme = Theme.of(context);
    final options = [
      {'label': '跟随系统', 'icon': Icons.auto_mode_rounded},
      {'label': '浅色模式', 'icon': Icons.light_mode_rounded},
      {'label': '深色模式', 'icon': Icons.dark_mode_rounded},
      {'label': '纯黑模式', 'icon': Icons.brightness_2_rounded},
    ];

    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = themeMode.value == index;

        return Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => themeMode.value = index,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      option['icon'] as IconData,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option['label'] as String,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  RadioGroup(
                    groupValue: themeMode.value,
                    onChanged: (v) => themeMode.value = v ?? 0,
                    child: Radio<int>(value: index),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLanguageSelector(BuildContext context, Signal<int> language) {
    final theme = Theme.of(context);
    final options = [
      {'label': '跟随系统', 'flag': '🌐'},
      {'label': '简体中文', 'flag': '🇨🇳'},
      {'label': 'English', 'flag': '🇺🇸'},
    ];

    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = language.value == index;

        return Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => language.value = index,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    option['flag'] as String,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option['label'] as String,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  RadioGroup(
                    groupValue: language.value,
                    onChanged: (v) => language.value = v ?? 0,
                    child: Radio<int>(value: index),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegionSelector(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('🇨🇳', style: TextStyle(fontSize: 20)),
      ),
      title: const Text('地区'),
      subtitle: const Text('中国大陆'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        final regions = [
          {'code': 'CN', 'name': '中国大陆', 'flag': '🇨🇳'},
          {'code': 'HK', 'name': '中国香港', 'flag': '🇭🇰'},
          {'code': 'TW', 'name': '中国台湾', 'flag': '🇹🇼'},
          {'code': 'US', 'name': '美国', 'flag': '🇺🇸'},
          {'code': 'GB', 'name': '英国', 'flag': '🇬🇧'},
          {'code': 'JP', 'name': '日本', 'flag': '🇯🇵'},
          {'code': 'KR', 'name': '韩国', 'flag': '🇰🇷'},
          {'code': 'SG', 'name': '新加坡', 'flag': '🇸🇬'},
          {'code': 'MY', 'name': '马来西亚', 'flag': '🇲🇾'},
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
                    leading: Text(
                      region['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
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

        if (selectedRegion != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('地区已更改为：${selectedRegion['name']}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildSyncFrequencySelector(
    BuildContext context,
    Signal<int> syncInterval,
  ) {
    final theme = Theme.of(context);
    final options = [
      {'label': '手动同步', 'icon': Icons.sync_disabled_rounded},
      {'label': '每天一次', 'icon': Icons.sync_rounded},
      {'label': '每周一次', 'icon': Icons.calendar_today_rounded},
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await showModalBottomSheet<int>(
            context: context,
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  return ListTile(
                    leading: Icon(
                      option['icon'] as IconData,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(option['label'] as String),
                    onTap: () => Navigator.pop(context, index),
                  );
                }).toList(),
              ),
            ),
          );
          if (result != null) {
            syncInterval.value = result;
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  options[syncInterval.value]['icon'] as IconData,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                options[syncInterval.value]['label'] as String,
                style: theme.textTheme.bodyLarge,
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCacheCleaner(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              theme.colorScheme.secondary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.cleaning_services_rounded,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      ),
      title: const Text('清理缓存'),
      subtitle: Text(cacheSize.value),
      trailing: isClearing.value
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
      onTap: isClearing.value ? null : _clearCache,
    );
  }

  Widget _buildStorageLocationSelector(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.folder_rounded,
          color: theme.colorScheme.primary,
          size: 24,
        ),
      ),
      title: const Text('书籍存储位置'),
      subtitle: const Text('内部存储/Documents/ZephyrReader/books'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () async {
        // TODO: 实现存储位置选择
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('存储位置选择功能开发中'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  Widget _buildBackupItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              iconColor.withValues(alpha: 0.1),
              iconColor.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
      onTap: isLoading ? null : onTap,
    );
  }

  Widget _buildSwitchSetting(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData? icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null
          ? Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            )
          : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
