import 'package:flutter/material.dart';

class SettingsNavigationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color iconColor;
  final Color iconBackground;
  final Widget? iconWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsNavigationTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.iconColor = Colors.white,
    this.iconBackground = Colors.blue,
    this.iconWidget,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (iconWidget != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: iconWidget,
              )
            else if (icon != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.3),
                ),
          ],
        ),
      ),
    );
  }
}
