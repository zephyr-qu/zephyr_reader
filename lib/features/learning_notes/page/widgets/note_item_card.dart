import 'package:zephyr_reader/src/rust/domain/note/models.dart';
import 'package:zephyr_reader/features/learning_notes/domain/note_with_book.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:zephyr_reader/core/utils/time_formatters.dart';


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
    final animDelay = Duration(milliseconds: 50 * index.clamp(0, 10));

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
