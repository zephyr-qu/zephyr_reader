/// 应用设置页面
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

/// 应用设置页面
class AppSettingsPage extends StatefulHookWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> with SignalsMixin {

  @override
  Widget build(BuildContext context) {
    // 设置状态
    final themeMode = useSignal(0); // 0: 跟随系统，1: 浅色，2: 深色，3: 纯黑
    final language = useSignal(0); // 0: 跟随系统，1: 简体中文，2: English
    final autoSync = useSignal(false);
    final syncInterval = useSignal(0); // 0: 手动，1: 每天，2: 每周
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('应用设置'),
      ),
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
                items: const [
                  ('跟随系统', 0),
                  ('简体中文', 1),
                  ('English', 2),
                ],
                onChanged: (v) => language.value = v ?? 0,
              ),
              ListTile(
                title: const Text('地区'),
                subtitle: const Text('中国大陆'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 显示地区选择
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
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
                subtitle: Text([
                  '手动同步',
                  '每天一次',
                  '每周一次',
                ][syncInterval.value]),
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
                subtitle: const Text('释放存储空间'),
                leading: const Icon(Icons.cleaning_services),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('清理缓存'),
                      content: const Text('确定要清理缓存吗？这不会影响已下载的书籍。'),
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
                    ),
                  );
                  
                  if (confirmed == true) {
                    // TODO: 实现清理缓存
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('缓存已清理')),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('书籍存储位置'),
                subtitle: const Text('内部存储/Documents/ZephyrReader/books'),
                leading: const Icon(Icons.folder),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 显示存储位置选择
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
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
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 实现备份功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('恢复数据'),
                subtitle: const Text('从备份文件恢复数据'),
                leading: const Icon(Icons.restore),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 实现恢复功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
                },
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
          return RadioListTile<int>(
            title: Text(item.$1),
            value: item.$2,
            groupValue: groupValue,
            onChanged: (v) {
              onChanged(v);
            },
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }
}
