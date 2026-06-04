import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_status_chip.dart';
import 'package:zephyr_reader/src/rust/storage/vocab_status_extension.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// A single vocabulary list item with swipe-to-delete and status popup menu.
///
/// Composes a [Dismissible] wrapping a [ListTile] with word info,
/// a subtitle built from pinyin/book context, and a trailing
/// [PopupMenuButton] that uses [VocabStatusChip] as the trigger.
class VocabListItemTile extends StatelessWidget {
  final Vocab item;
  final Map<String, String> bookTitles;
  final ThemeData theme;
  final VoidCallback onDismissed;
  final ValueChanged<VocabStatus> onUpdateStatus;

  const VocabListItemTile({
    super.key,
    required this.item,
    required this.bookTitles,
    required this.theme,
    required this.onDismissed,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: theme.colorScheme.error,
          child: const Icon(
            PhosphorIconsRegular.trash,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (_) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定要删除「${item.word}」吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('删除'),
                ),
              ],
            ),
          );
          return confirmed ?? false;
        },
        onDismissed: (_) => onDismissed(),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            vertical: DesignTokens.spacing(Spacing.xs),
          ),
          title: Text(
            item.word,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: _buildSubtitle(),
          trailing: PopupMenuButton<VocabStatus>(
            initialValue: item.status,
            onSelected: onUpdateStatus,
            itemBuilder: (_) => [
              if (item.status != VocabStatus.unstarted)
                PopupMenuItem(
                  value: VocabStatus.unstarted,
                  child: Text(VocabStatus.unstarted.displayName),
                ),
              if (item.status != VocabStatus.learning)
                PopupMenuItem(
                  value: VocabStatus.learning,
                  child: Text(VocabStatus.learning.displayName),
                ),
              if (item.status != VocabStatus.mastered)
                PopupMenuItem(
                  value: VocabStatus.mastered,
                  child: Text(VocabStatus.mastered.displayName),
                ),
              if (item.status != VocabStatus.ignored)
                PopupMenuItem(
                  value: VocabStatus.ignored,
                  child: Text(VocabStatus.ignored.displayName),
                ),
            ],
            child: VocabStatusChip(status: item.status, theme: theme),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final parts = <String>[];
    if (item.pinyin.isNotEmpty) {
      parts.add(item.pinyin);
    }
    if (item.bookId != null && item.bookId!.isNotEmpty) {
      final title = bookTitles[item.bookId];
      if (title != null && title.isNotEmpty) {
        parts.add('来自《$title》');
      }
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
