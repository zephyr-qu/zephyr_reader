import 'package:flutter/material.dart';

class SettingsCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Widget> children;
  final bool showDividers;

  const SettingsCard({
    super.key,
    required this.colorScheme,
    required this.children,
    this.showDividers = false,
  });

  @override
  Widget build(BuildContext context) {
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
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              if (i > 0 && showDividers)
                Divider(
                  height: 0.5,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                ),
              if (showDividers)
                children[i]
              else
                Padding(padding: const EdgeInsets.all(16), child: children[i]),
            ],
          );
        }),
      ),
    );
  }
}
