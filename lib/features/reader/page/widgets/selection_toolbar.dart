import 'package:flutter/material.dart';

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
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.highlight_alt,
              label: '高亮',
              color: const Color(0xFFFFEB3B),
              onTap: onHighlight,
            ),
            const SizedBox(width: 4),
            _ActionButton(
              icon: Icons.note_add,
              label: '笔记',
              color: theme.colorScheme.primary,
              onTap: onAnnotate,
            ),
            if (onLookup != null) ...[
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.book,
                label: '查词',
                color: const Color(0xFF4CAF50),
                onTap: onLookup!,
              ),
            ],
            if (onAddToVocabulary != null) ...[
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.playlist_add,
                label: '生词本',
                color: const Color(0xFF9C27B0),
                onTap: onAddToVocabulary!,
              ),
            ],
            if (onBilingualHighlight != null) ...[
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.compare_arrows,
                label: '标注两侧',
                color: const Color(0xFFE91E63),
                onTap: onBilingualHighlight!,
              ),
            ],
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

