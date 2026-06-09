import 'package:flutter/material.dart';

/// 设置页卡片容器。
///
/// 将子组件放在带边框和圆角的卡片中，可选显示分割线。
class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool showDividers;

  const SettingsCard({
    super.key,
    required this.children,
    this.showDividers = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0 && showDividers)
              Divider(
                height: 0.5,
                thickness: 0.5,
                color: colorScheme.outlineVariant.withValues(alpha: 0.15),
              ),
            if (showDividers)
              children[i]
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: children[i],
              ),
          ],
        ],
      ),
    );
  }
}
