import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('快捷主题',
                  style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: AppThemeType.values.map((type) {
                    final selected = ThemeManager.instance.themeType.value == type;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => ThemeManager.instance.setThemeType(type),
                        child: Column(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _themePreviewColor(type),
                                border: Border.all(
                                  color: selected ? DesignTokens.primary : DesignTokens.divider,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              child: selected
                                ? Icon(Icons.check, size: 14,
                                    color: type == AppThemeType.light || type == AppThemeType.eyeProtection
                                      ? DesignTokens.primary : Colors.white)
                                : null,
                            ),
                            const SizedBox(height: 4),
                            Text(type.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: selected ? DesignTokens.primary : DesignTokens.textSecondary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
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
          _buildSettingsSection(
            context,
            icon: Icons.sync_rounded,
            title: '数据同步',
            subtitle: 'WebDAV 云端同步',
            onTap: () => context.push(RoutePaths.sync),
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

  Color _themePreviewColor(AppThemeType type) {
    switch (type) {
      case AppThemeType.light:
        return const Color(0xFFF5F5F5);
      case AppThemeType.dark:
        return const Color(0xFF2D2D2D);
      case AppThemeType.pureDark:
        return const Color(0xFF000000);
      case AppThemeType.eyeProtection:
        return const Color(0xFFF5E6C8);
      case AppThemeType.system:
        return const Color(0xFFB0B0B0);
    }
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 22,
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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }
}
