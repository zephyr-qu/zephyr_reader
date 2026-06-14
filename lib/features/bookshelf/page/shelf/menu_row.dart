import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: IconSize.leading,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
