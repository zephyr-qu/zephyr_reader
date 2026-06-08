import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_status_chip.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// A single vocabulary list item with swipe-to-delete and status popup menu.
///
/// Composes a [Dismissible] wrapping a card-like row with word info,
/// translation, book/source context, a status dot indicator, and a trailing
/// [PopupMenuButton] that uses [VocabStatusChip] as the trigger.
class VocabListItemTile extends StatelessWidget {
  final Vocab item;
  final Map<String, String> bookTitles;
  final VoidCallback onDismissed;
  final ValueChanged<VocabStatus> onUpdateStatus;
  final int index;

  const VocabListItemTile({
    super.key,
    required this.item,
    required this.bookTitles,
    required this.onDismissed,
    required this.onUpdateStatus,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = vocabStatusColor(item.status, theme);
    final bookTitle = bookTitles[item.bookId];
    final l10n = AppLocalizations.of(context)!;
    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: cs.error,
          child: const Icon(PhosphorIconsRegular.trash, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.confirmDelete),
              content: Text(l10n.confirmDeleteWord(item.word)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.delete),
                ),
              ],
            ),
          );
          return confirmed ?? false;
        },
        onDismissed: (_) => onDismissed(),
        child: _buildItemCard(cs, statusColor, bookTitle, l10n),
      ),
    );
  }

  Widget _buildItemCard(
    ColorScheme cs,
    Color statusColor,
    String? bookTitle,
    AppLocalizations l10n,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status dot indicator
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 4, right: 12),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            // Main content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Word + pinyin row
                  Row(
                    children: [
                      Text(
                        item.word,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if (item.pinyin.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '/${item.pinyin}/',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Translation
                  if (item.translation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.translation,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  // Book title + wordList badge
                  if (bookTitle != null || item.wordList != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (bookTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIconsRegular.book,
                                  size: 10,
                                  color: cs.primary.withValues(alpha: 0.8),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  bookTitle,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: cs.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.wordList != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.wordList!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: cs.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Status popup button
            PopupMenuButton<VocabStatus>(
              initialValue: item.status,
              onSelected: onUpdateStatus,
              itemBuilder: (_) => [
                if (item.status != VocabStatus.unstarted)
                  PopupMenuItem(
                    value: VocabStatus.unstarted,
                    child: Text(l10n.statusUnlearned),
                  ),
                if (item.status != VocabStatus.learning)
                  PopupMenuItem(
                    value: VocabStatus.learning,
                    child: Text(l10n.statusLearning),
                  ),
                if (item.status != VocabStatus.mastered)
                  PopupMenuItem(
                    value: VocabStatus.mastered,
                    child: Text(l10n.statusMastered),
                  ),
                if (item.status != VocabStatus.ignored)
                  PopupMenuItem(
                    value: VocabStatus.ignored,
                    child: Text(l10n.statusIgnored),
                  ),
              ],
              child: VocabStatusChip(status: item.status),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: 300.ms,
      delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
    );
  }
}
