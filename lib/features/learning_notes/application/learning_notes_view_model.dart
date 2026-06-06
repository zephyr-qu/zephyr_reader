import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class LearningNotesViewModel {
  final noteList = asyncSignal<List<NoteWithBook>>(AsyncState.data([]));
  final noteTotalCount = asyncSignal<int>(AsyncState.loading());
  final noteFilterBookId = signal<String?>(null);

  /// 用于筛选芯片的书籍标题映射（仅 UI 筛选用，笔记自己已带书名）
  final filterBookTitles = asyncSignal<Map<String, String>>(
    AsyncState.data({}),
  );

  /// 重新加载全部数据（笔记列表、笔记总数、书籍标题）。
  Future<void> refresh() async {
    try {
      await loadAll();
    } catch (e) {
      Logging.error('Refresh failed: $e');
    }
  }

  /// 加载笔记列表、笔记总数和筛选书籍列表。
  Future<void> loadAll() async {
    await Future.wait([_loadBookTitles(), _loadNotes()]);
  }

  Future<void> setNoteFilterBook(String? bookId) async {
    noteFilterBookId.value = bookId;
    await _loadNotes();
  }

  Future<void> _loadNotes({int limit = 200}) async {
    try {
      final results = await Future.wait([
        note_api.listNotesWithTitles(limit: limit, offset: 0),
        note_api.countNotes(bookId: noteFilterBookId.value),
      ]);
      noteList.value = AsyncState.data(results[0] as List<NoteWithBook>);
      noteTotalCount.value = AsyncState<int>.data(results[1] as int);
    } catch (e) {
      noteList.value = AsyncState.error(e);
      noteTotalCount.value = AsyncState.error(e);
    }
  }

  /// 加载书籍标题，与笔记查询并行。
  Future<void> _loadBookTitles() async {
    try {
      final titles = await book_api.mapBookTitles();
      filterBookTitles.value = AsyncState.data(titles);
    } catch (e) {
      filterBookTitles.value = AsyncState.error(e);
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    noteList.dispose();
    noteTotalCount.dispose();
    noteFilterBookId.dispose();
    filterBookTitles.dispose();
  }
}
