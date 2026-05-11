/// 笔记服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 笔记服务
@injectable
class NoteService {
  final RustStorageService _storage;
  NoteService(this._storage);

  /// 获取笔记统计
  Future<NoteStats> getNoteStats(String bookId) async {
    return _storage.getNoteStats('book_$bookId');
  }

  /// 获取笔记列表
  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async {
    return _storage.getNotes('book_$bookId', noteType: noteType);
  }

  /// 创建笔记
  Future<Note> createNote(Note note) async {
    return _storage.createNote(note);
  }

  /// 删除笔记
  Future<void> deleteNote(String noteId) async {
    await _storage.deleteNote(noteId);
  }
}
