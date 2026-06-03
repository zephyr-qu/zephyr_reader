import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/core/utils/date_formatters.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';

import 'package:zephyr_reader/src/rust/storage/models.dart';

class LearningNotesNoteTab extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<NoteWithBook> noteList;
  final bool noteLoading;
  final String? filterBookId;
  final Map<String, String> bookTitles;
  final LearningNotesViewModel vm;

  const LearningNotesNoteTab({
    super.key,
    required this.colorScheme,
    required this.noteList,
    required this.noteLoading,
    required this.filterBookId,
    required this.bookTitles,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    if (noteLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _buildNoteFilters(),
        Expanded(child: _buildNoteList(context)),
      ],
    );
  }

  Widget _buildNoteFilters() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _noteFilterChip(
            '全部书籍',
            null,
            selected: filterBookId == null,
            onTap: () => vm.setNoteFilterBook(null),
          ),
          for (final entry in bookTitles.entries)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _noteFilterChip(
                entry.value,
                entry.key,
                selected: filterBookId == entry.key,
                onTap: () => vm.setNoteFilterBook(entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noteFilterChip(
    String label,
    String? bookId, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SelectionChip(
      label: label,
      selected: selected,
      colorScheme: colorScheme,
      onTap: onTap,
      activeColor: const Color(0xFFFFA726),
    );
  }

  Widget _buildNoteList(BuildContext context) {
    final cs = colorScheme;
    if (noteList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.notePencil,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无笔记',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '在阅读中做笔记后，它们会出现在这里',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/bookshelf'),
              icon: const Icon(PhosphorIconsRegular.books, size: 16),
              label: const Text('去阅读'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: noteList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildNoteItem(cs, noteList[i], i),
    );
  }

  Widget _buildNoteItem(ColorScheme cs, NoteWithBook item, int index) {
    final note = item.note;
    final animDelay = (50 * index.clamp(0, 10)).ms;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFFFFA726), width: 3),
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
            if (note.selectedText != null && note.selectedText!.isNotEmpty) ...[
              Text(
                note.selectedText!,
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
