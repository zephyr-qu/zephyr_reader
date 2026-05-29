import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class NoteManageViewModel {
  final String bookId;
  final String bookTitle;

  final notes = signal<List<Note>>([]);
  final loading = signal(true);

  NoteManageViewModel({required this.bookId, required this.bookTitle}) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    loading.value = true;
    try {
      notes.value = await note_api.listNotesByBook(bookId: bookId);
    } catch (_) {
      notes.value = [];
    }
    loading.value = false;
  }

  Future<String> renderNotesToString({
    required List<Note> notes,
    required String format,
  }) async {
    return note_api.renderNotesToString(
      notes: notes,
      bookTitle: bookTitle,
      format: format,
    );
  }

  void dispose() {
    notes.dispose();
    loading.dispose();
  }
}
