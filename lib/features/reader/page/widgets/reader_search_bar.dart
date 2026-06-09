import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 阅读器内搜索栏。
///
/// 提供关键词搜索、匹配导航和关闭功能。
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        color: theme.colorScheme.surfaceContainerHigh,
          padding: EdgeInsets.only(
            left: DesignTokens.spacing(Spacing.sm),
            right: DesignTokens.spacing(Spacing.sm),
            bottom: DesignTokens.spacing(Spacing.xs),
          ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(PhosphorIconsLight.caretLeft, size: 20),
              onPressed: onClose,
              tooltip: l10n.closeSearch,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: l10n.searchInChapterHint,
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
              tooltip: l10n.prev,
            ),
            IconButton(
              icon: const Icon(PhosphorIconsLight.caretRight, size: 20),
              onPressed: matchCount > 0 ? onNext : null,
              tooltip: l10n.next,
            ),
          ],
        ),
      ),
    );
  }
}
