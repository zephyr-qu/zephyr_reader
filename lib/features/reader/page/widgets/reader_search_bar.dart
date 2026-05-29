library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class ReaderSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int matchCount;
  final int currentIndex;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const ReaderSearchBar({
    super.key,
    required this.controller,
    required this.matchCount,
    required this.currentIndex,
    required this.onChanged,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: DesignTokens.spacing(Spacing.sm),
        right: DesignTokens.spacing(Spacing.sm),
        bottom: DesignTokens.spacing(Spacing.xs),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsLight.caretLeft, size: 20),
              onPressed: onClose,
              tooltip: '关闭搜索',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: '在章节内搜索...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: DesignTokens.spacing(Spacing.sm),
                  ),
                  suffixText: matchCount > 0 ? '$currentIndex/$matchCount' : '',
                  suffixStyle: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(PhosphorIconsLight.caretLeft, size: 20),
              onPressed: matchCount > 0 ? onPrev : null,
              tooltip: '上一个',
            ),
            IconButton(
              icon: const Icon(PhosphorIconsLight.caretRight, size: 20),
              onPressed: matchCount > 0 ? onNext : null,
              tooltip: '下一个',
            ),
          ],
        ),
      ),
    );
  }
}
