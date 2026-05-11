import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _buildSettingsSection(
            context,
            icon: Icons.menu_book,
            title: '阅读设置',
            subtitle: '字体、字号、翻页模式等',
            onTap: () => context.push(RoutePaths.readingSettings),
          ),
          _buildSettingsSection(
            context,
            icon: Icons.palette,
            title: '主题设置',
            subtitle: '浅色、深色、纯黑、护眼模式',
            onTap: () => context.push(RoutePaths.themeSettings),
          ),
          _buildSettingsSection(
            context,
            icon: Icons.settings_applications,
            title: '应用设置',
            subtitle: '语言、同步、存储、备份',
            onTap: () => context.push(RoutePaths.appSettings),
          ),
          const SizedBox(height: 24),
          _buildSettingsSection(
            context,
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本信息、用户协议、隐私政策',
            onTap: () => context.push(RoutePaths.about),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zephyr Reader',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '版本 1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
