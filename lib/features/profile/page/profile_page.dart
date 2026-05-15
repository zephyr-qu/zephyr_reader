import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 60),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primary,
                child: const Text('书',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('书友',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimary, letterSpacing: -0.3),
                  ),
                  SizedBox(height: 2),
                  Text('阅读是一种生活态度',
                    style: TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 48),
          const Divider(height: 0.5),
          _menuItem(context, Icons.menu_book_outlined, '阅读设置', () => context.push(RoutePaths.readingSettings)),
          const Divider(height: 0.5),
          _menuItem(context, Icons.palette_outlined, '主题设置', () => context.push(RoutePaths.themeSettings)),
          const Divider(height: 0.5),
          _menuItem(context, Icons.settings_applications_outlined, '应用设置', () => context.push(RoutePaths.appSettings)),
          const Divider(height: 0.5),
          const SizedBox(height: 40),
          const Divider(height: 0.5),
          _menuItem(context, Icons.info_outline, '关于', () => context.push(RoutePaths.about)),
          const Divider(height: 0.5),
          const SizedBox(height: 48),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text('退出登录',
                style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('Zephyr Reader v1.0.0',
              style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: DesignTokens.textPrimary),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18, color: DesignTokens.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
    );
  }
}
