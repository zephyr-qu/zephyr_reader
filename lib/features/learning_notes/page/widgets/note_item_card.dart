import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/core/utils/format_utils.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// A single note card with left accent border, selected-text preview,
/// content body, and footer (type icon + book title + date).
///
/// Animates in with a staggered fadeIn using [staggerDelay(index)].
class NoteItemCard extends StatelessWidget {
  final NoteWithBook item;
  final int index;

  const NoteItemCard({super.key, required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = item.note;
    final animDelay = staggerDelay(index);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: cs.primary, width: 3),
          right: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.selectedText case final text? when text.isNotEmpty) ...[
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              note.content,
              style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  note.noteType == NoteType.highlight
                      ? PhosphorIconsRegular.highlighter
                      : PhosphorIconsRegular.pencilSimpleLine,
                  size: 12,
                  color: cs.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  item.bookTitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: cs.primary.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                Text(
                  formatDateYYYYMMDD(note.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: animDelay);
  }
}
