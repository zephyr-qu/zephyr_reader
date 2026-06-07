import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// 选择项磁贴组件，显示标签和当前值，点击触发选择操作。
///
/// 用于 TTS 设置页面中引擎选择等场景，视觉上与设置列表项风格一致。
class SelectItemTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const SelectItemTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
