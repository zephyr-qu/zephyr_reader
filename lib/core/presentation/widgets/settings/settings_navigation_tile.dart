import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 设置页导航条目。
///
/// 显示图标、标题、副标题和可选的尾部组件，点击时触发导航。
class SettingsNavigationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final MenuItemSemantic? semantic;
  final Widget? iconWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsNavigationTile({
    super.key,
    required this.title,
    this.subtitle = '',
    this.icon,
    this.semantic,
    this.iconColor,
    this.iconBackground,
    this.iconWidget,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ??
        (semantic?.iconColor(Theme.of(context).brightness) ?? cs.onPrimaryContainer);
    final effectiveIconBg = iconBackground ??
        (semantic?.iconBackground(Theme.of(context).brightness) ?? cs.primaryContainer);

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
                  color: effectiveIconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: iconWidget,
              )
            else if (icon != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: IconSize.inline, color: effectiveIconColor),
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
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
