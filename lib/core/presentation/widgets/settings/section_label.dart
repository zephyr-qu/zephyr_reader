import 'package:flutter/material.dart';

/// 设置页分区标签。
///
/// 显示带有标题文字和可选标签（tag）的分区标题。
class SectionLabel extends StatelessWidget {
  final String label;
  final Widget? tag;

  const SectionLabel({super.key, required this.label, this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              letterSpacing: 0.4,
            ),
          ),
          if (tag != null) ...[const SizedBox(width: 6), tag!],
        ],
      ),
    );
  }
}
