import 'package:flutter/material.dart';

/// 技术栈标签组件。
///
/// 在关于页面中展示应用使用的技术名称，带有语义颜色。
class TechChip extends StatelessWidget {
  final String label;
  final Color color;

  const TechChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final bg = brightness == Brightness.light
        ? color.withValues(alpha: 0.1)
        : color.withValues(alpha: 0.18);
    final fg = brightness == Brightness.light
        ? color
        : color.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
