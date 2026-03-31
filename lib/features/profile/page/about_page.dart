/// 关于页面
///
/// 显示应用信息、版本、许可证等
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 关于页面
class AboutPage extends HookWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packageInfo = useFuture(useMemoized(() => PackageInfo.fromPlatform()));
    
    final version = packageInfo.data?.version ?? '未知';
    final buildNumber = packageInfo.data?.buildNumber ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        children: [
          // 应用图标和名称
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  Icons.menu_book,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Zephyr Reader',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '如和风般轻盈的阅读体验',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Chip(
                  label: Text('v$version ($buildNumber)'),
                  avatar: const Icon(Icons.info_outline, size: 16),
                ),
              ],
            ),
          ),
          
          // 应用介绍
          _buildSection(
            context,
            title: '应用介绍',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Zephyr Reader 是一款基于 Flutter + Rust 架构开发的安卓端双语离线小说阅读器。'
                  '项目采用纯本地设计，无后台、无广告、无数据收集，专注于中文、英文双语小说的阅读体验。',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          
          // 核心特性
          _buildSection(
            context,
            title: '核心特性',
            children: [
              _buildFeatureItem(
                context,
                icon: Icons.cloud_off,
                title: '纯离线使用',
                subtitle: '核心功能 100% 离线可用',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: Icons.speed,
                title: '高性能解析',
                subtitle: 'Rust 实现文本解析，大文件加载流畅',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: Icons.translate,
                title: '双语排版',
                subtitle: '中文、英文同等优先的排版优化',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: Icons.palette,
                title: '多主题支持',
                subtitle: '亮色/深色/纯黑夜间主题',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: Icons.devices,
                title: '设备适配',
                subtitle: '手机、平板双端自适应',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: Icons.sync,
                title: 'WebDAV 同步',
                subtitle: '支持跨设备数据同步与备份',
              ),
            ],
          ),
          
          // 技术栈
          _buildSection(
            context,
            title: '技术栈',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(label: Text('Flutter 3.22')),
                    Chip(label: Text('Rust 1.75')),
                    Chip(label: Text('Drift')),
                    Chip(label: Text('signals_flutter')),
                    Chip(label: Text('go_router')),
                    Chip(label: Text('flutter_rust_bridge')),
                  ],
                ),
              ),
            ],
          ),
          
          // 更多信息
          _buildSection(
            context,
            title: '更多信息',
            children: [
              ListTile(
                title: const Text('检查更新'),
                leading: const Icon(Icons.system_update),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已是最新版本')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('用户协议'),
                leading: const Icon(Icons.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 显示用户协议
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('隐私政策'),
                leading: const Icon(Icons.privacy_tip),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: 显示隐私政策
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('开源许可证'),
                leading: const Icon(Icons.gavel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Zephyr Reader',
                    applicationVersion: version,
                    applicationLegalese: 'MIT License',
                  );
                },
              ),
            ],
          ),
          
          // 联系方式
          _buildSection(
            context,
            title: '联系方式',
            children: [
              ListTile(
                title: const Text('问题反馈'),
                subtitle: const Text('提交 Issue'),
                leading: const Icon(Icons.bug_report),
                trailing: const Icon(Icons.open_in_new),
                onTap: () {
                  // TODO: 打开 GitHub Issues
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('功能开发中...')),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 版权信息
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© 2026 Zephyr Reader\nMade with ❤️ by Flutter + Rust',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
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
  
  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
