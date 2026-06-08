import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 个人中心统计项组件。
///
/// 显示数值、标签和图标的三列统计卡片。
class ProfileStatItem extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final IconData icon;

  const ProfileStatItem({
    super.key,
    required this.value,
    this.unit,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
      height: 1.1,
    );

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: DesignTokens.warmAccent),
          const SizedBox(height: 6),
          if (unit != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: textStyle),
                const SizedBox(width: 1),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          else
            Text(value, style: textStyle),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
