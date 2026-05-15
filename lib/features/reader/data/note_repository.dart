/// 笔记仓库
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable()
class NoteRepository {
  final RustStorageService _storage;
  NoteRepository(this._storage);

  Future<NoteStats> getNoteStats(String bookId) async {
    return _storage.getNoteStats(bookId);
  }

  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async {
    return _storage.getNotes(bookId, noteType: noteType);
  }

  Future<Note> createNote(Note note) async {
    return _storage.createNote(note);
  }

  Future<void> deleteNote(String noteId) async {
    await _storage.deleteNote(noteId);
  }
}
