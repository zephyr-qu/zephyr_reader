import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// 文本选择工具栏。
///
/// 选中文本后弹出的浮动工具栏，提供高亮、笔记、查词、加入生词本等操作。
class SelectionToolbar extends StatelessWidget {
  final String selectedText;
  final VoidCallback onHighlight;
  final VoidCallback onAnnotate;
  final VoidCallback? onLookup;
  final VoidCallback? onAddToVocabulary;
  final VoidCallback? onBilingualHighlight;
  final VoidCallback onDismiss;

  const SelectionToolbar({
    super.key,
    required this.selectedText,
    required this.onHighlight,
    required this.onAnnotate,
    this.onLookup,
    this.onAddToVocabulary,
    this.onBilingualHighlight,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1A1A24) : const Color(0xFFFFFDF7))
                .withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.08,
              ),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionChip(
                icon: PhosphorIconsRegular.highlighter,
                label: l10n.selectionHighlight,
                iconColor: const Color(0xFFFFEB3B),
                onTap: onHighlight,
              ),
              const SizedBox(width: 4),
              _ActionChip(
                icon: PhosphorIconsRegular.notePencil,
                label: l10n.selectionNote,
                iconColor: theme.colorScheme.primary,
                onTap: onAnnotate,
              ),
              if (onLookup != null) ...[
                const SizedBox(width: 4),
                _ActionChip(
                  icon: PhosphorIconsRegular.bookOpenText,
                  label: l10n.lookupWord,
                  iconColor: const Color(0xFF4CAF50),
                  onTap: onLookup!,
                ),
              ],
              if (onAddToVocabulary != null) ...[
                const SizedBox(width: 4),
                _ActionChip(
                  icon: PhosphorIconsRegular.listPlus,
                  label: l10n.selectionVocabulary,
                  iconColor: const Color(0xFF9C27B0),
                  onTap: onAddToVocabulary!,
                ),
              ],
              if (onBilingualHighlight != null) ...[
                const SizedBox(width: 4),
                _ActionChip(
                  icon: PhosphorIconsRegular.arrowsLeftRight,
                  label: l10n.selectionBilingual,
                  iconColor: const Color(0xFFE91E63),
                  onTap: onBilingualHighlight!,
                ),
              ],
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(14), // 16 icon + 28 = 44px
                  child: Icon(
                    PhosphorIconsRegular.x,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        hapticFeedback(HapticType.selection);
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
