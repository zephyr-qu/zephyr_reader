import 'package:flutter/material.dart';

/// 可选中标签组件。
///
/// 显示一个带选中态高亮的圆角标签，支持自定义颜色和动画过渡。
class SelectionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;
  final EdgeInsets padding;
  final double fontSize;
  final double borderRadius;
  final Color? inactiveBgColor;

  const SelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.fontSize = 12,
    this.borderRadius = 16,
    this.inactiveBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = activeColor ?? colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: padding,
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : (inactiveBgColor ?? colorScheme.surface),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: selected
                  ? color
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? color : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
