import 'package:flutter/material.dart';

/// 设置页面的统一 AppBar，提供一致的标题样式。
class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final FontWeight? fontWeight;

  const SettingsAppBar({super.key, required this.title, this.fontWeight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 22,
          fontWeight: fontWeight ?? FontWeight.w700,
          color: cs.onSurface,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
