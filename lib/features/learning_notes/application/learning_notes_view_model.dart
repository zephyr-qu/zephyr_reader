import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 学习笔记 ViewModel。
///
/// 管理笔记/高亮列表、总数统计和按书籍的分组。
class LearningNotesViewModel {
  final noteList = asyncSignal<List<NoteWithBook>>(AsyncState.data([]));

  final noteTotalCount = asyncSignal<int>(AsyncState.loading());

  /// 按书籍分组后的笔记列表（按笔记数量降序排列）。
  List<NoteGroup> get groupedNotes {
    final data = noteList.value.value;
    if (data == null || data.isEmpty) return [];
    final map = <String, NoteGroup>{};
    for (final n in data) {
      final key = n.note.bookId;
      map.putIfAbsent(
        key,
        () => NoteGroup(bookId: key, bookTitle: n.bookTitle, notes: []),
      );
      map[key]!.notes.add(n);
    }
    return map.values.toList()
      ..sort((a, b) => b.notes.length.compareTo(a.notes.length));
  }

  /// 重新加载全部数据（笔记列表、笔记总数）。
  Future<void> refresh() async {
    try {
      await loadAll();
    } catch (e) {
      Logging.error('Refresh failed: $e');
    }
  }

  /// 加载笔记列表和笔记总数。
  Future<void> loadAll() async {
    await _loadNotes();
  }

  Future<void> _loadNotes({int limit = 200}) async {
    try {
      final results = await Future.wait([
        note_api.listNotesWithTitles(limit: limit, offset: 0),
        note_api.countNotes(),
      ]);
      noteList.value = AsyncState.data(results[0] as List<NoteWithBook>);
      noteTotalCount.value = AsyncState<int>.data(results[1] as int);
    } catch (e) {
      noteList.value = AsyncState.error(e);
      noteTotalCount.value = AsyncState.error(e);
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    noteList.dispose();
    noteTotalCount.dispose();
  }
}

/// 同一本书的笔记分组。
class NoteGroup {
  final String bookId;
  final String bookTitle;
  final List<NoteWithBook> notes;

  NoteGroup({
    required this.bookId,
    required this.bookTitle,
    required this.notes,
  });
}
