import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/go_reading_empty_state.dart';
import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/note_item_card.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Notes tab showing filter chips and a scrollable list of note cards.
///
/// Derives [colorScheme] from [BuildContext]. Accepts an
/// [onNoteFilterChanged] callback instead of a ViewModel reference.
class LearningNotesNoteTab extends StatelessWidget {
  final List<NoteWithBook> noteList;
  final String? filterBookId;
  final Map<String, String> bookTitles;
  final ValueChanged<String?> onNoteFilterChanged;

  const LearningNotesNoteTab({
    super.key,
    required this.noteList,
    required this.filterBookId,
    required this.bookTitles,
    required this.onNoteFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _buildNoteFilters(l10n, cs),
        Expanded(child: _buildNoteList(l10n, cs)),
      ],
    );
  }

  Widget _buildNoteFilters(AppLocalizations l10n, ColorScheme cs) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          SelectionChip(
            label: l10n.allBooks,
            selected: filterBookId == null,
            onTap: () => onNoteFilterChanged(null),
          ),
          for (final entry in bookTitles.entries)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: SelectionChip(
                label: entry.value,
                selected: filterBookId == entry.key,
                onTap: () => onNoteFilterChanged(entry.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteList(AppLocalizations l10n, ColorScheme cs) {
    if (noteList.isEmpty) {
      return GoReadingEmptyState(
        icon: PhosphorIconsRegular.notePencil,
        title: l10n.noNotes,
        subtitle: l10n.noteEmptyHint,
        buttonLabel: l10n.goReading,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: noteList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => NoteItemCard(item: noteList[i], index: i),
    );
  }
}
