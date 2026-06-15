import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/go_reading_empty_state.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/note_item_card.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 按书籍分组的笔记列表。
///
/// 将笔记按书籍分组展示，每组包含一个书籍标题头和其下的笔记卡片。
/// 不再使用横向滚动的书籍筛选标签，避免书籍过多时无法操作。
class LearningNotesNoteList extends StatelessWidget {
  final List<NoteGroup> groups;

  const LearningNotesNoteList({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (groups.isEmpty) {
      return GoReadingEmptyState(
        icon: PhosphorIconsRegular.notePencil,
        title: l10n.noNotes,
        subtitle: l10n.noteEmptyHint,
        buttonLabel: l10n.goReading,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _totalItemCount(groups),
      itemBuilder: (context, index) => _buildItem(context, index),
    );
  }

  static int _totalItemCount(List<NoteGroup> groups) {
    // Each group: 1 header + N notes + 1 bottom spacer
    int count = 0;
    for (final g in groups) {
      count += 1 + g.notes.length + 1;
    }
    return count;
  }

  Widget _buildItem(BuildContext context, int index) {
    int cursor = 0;
    for (final group in groups) {
      // Header
      if (index == cursor) {
        return _buildBookHeader(context, group);
      }
      cursor++;

      // Notes
      final notesEnd = cursor + group.notes.length;
      if (index < notesEnd) {
        return NoteItemCard(item: group.notes[index - cursor], index: index);
      }
      cursor = notesEnd;

      // Bottom spacer
      if (index == cursor) {
        return const SizedBox(height: 12);
      }
      cursor++;
    }
    // Should never reach here
    return const SizedBox.shrink();
  }

  Widget _buildBookHeader(BuildContext context, NoteGroup group) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.bookOpen, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              group.bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${group.notes.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
