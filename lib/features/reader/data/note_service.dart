/// 笔记服务
library;

import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 笔记服务
class NoteService {
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  static NoteService get instance => _instance;

  final _storage = RustStorageService();

  /// 获取笔记统计
  Map<String, int> getNoteStats(String bookId) {
    return _storage.getNoteStats('book_$bookId');
  }

  /// 获取笔记列表
  List<DbNote> getNotes(String bookId, {DbNoteType? noteType}) {
    return _storage.getNotes('book_$bookId', noteType: noteType);
  }

  /// 创建笔记
  DbNote createNote(DbNote note) {
    return _storage.createNote(note);
  }

  /// 删除笔记
  void deleteNote(String noteId) {
    _storage.deleteNote(noteId);
  }
}
