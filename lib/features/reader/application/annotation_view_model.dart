import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/page/renderer/highlight_painter.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 划词批注视图模型。
///
/// 管理选区文本、高亮和笔记的加载、保存、删除。
/// 不持有 ViewModel 引用，所有依赖通过构造注入。
class AnnotationViewModel {
  final Signal<String> _bookId;
  final Signal<int> _chapterIndex;

  /// 高亮/笔记缓存（按章节索引），避免切换章节时重复 API 调用。
  final Map<int, List<Note>> highlightsCache = {};

  final selectedText = signal<String>('');
  final selectionStart = signal<int>(0);
  final selectionEnd = signal<int>(0);
  final highlights = asyncSignal<List<Note>>(AsyncState.data([]));

  AnnotationViewModel(this._bookId, this._chapterIndex);

  /// 加载当前章节的全部高亮和笔记。
  ///
  /// [forceRefresh] 为 `true` 时绕过缓存，强制从 API 重新获取。
  Future<void> loadHighlights({bool forceRefresh = false}) async {
    final idx = _chapterIndex.value;
    if (!forceRefresh) {
      final cached = highlightsCache[idx];
      if (cached != null) {
        highlights.value = AsyncState.data(cached);
        return;
      }
    }
    try {
      final notes = await note_api.listNotesInChapter(
        bookId: _bookId.value,
        chapterIndex: idx,
      );
      highlightsCache[idx] = notes;
      highlights.value = AsyncState.data(notes);
    } catch (_) {
      highlights.value = AsyncState.data([]);
    }
    HighlightPainter.invalidateCache();
  }

  /// 更新当前选中的文本范围和内容。
  void updateSelection(String text, int start, int end) {
    selectedText.value = text;
    selectionStart.value = start;
    selectionEnd.value = end;
  }

  /// 清除当前选中文本并隐藏工具栏。
  void clearSelection() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
  }

  /// 保存当前选中的文本为高亮。
  Future<void> saveHighlight() async {
    if (selectedText.value.isEmpty) return;
    try {
      await note_api.createHighlight(
        bookId: _bookId.value,
        chapterIndex: _chapterIndex.value,
        charOffset: selectionStart.value,
        length: selectionEnd.value - selectionStart.value,
        selectedText: selectedText.value,
        color: 0xFFFFEB3B,
      );
      await loadHighlights(forceRefresh: true);
      clearSelection();
    } catch (_) {
      // toastMessage 由调用方设置
      rethrow;
    }
  }

  /// 保存当前选中的文本为笔记。
  Future<void> saveAnnotation(String annotationContent) async {
    if (selectedText.value.isEmpty || annotationContent.isEmpty) return;
    try {
      await note_api.createAnnotation(
        bookId: _bookId.value,
        chapterIndex: _chapterIndex.value,
        charOffset: selectionStart.value,
        content: annotationContent,
        selectedText: selectedText.value,
      );
      await loadHighlights(forceRefresh: true);
      clearSelection();
    } catch (_) {
      rethrow;
    }
  }

  /// 删除指定笔记或高亮（FFI 调用）。
  Future<void> deleteNote(String noteId) async {
    await note_api.deleteNote(noteId: noteId);
    await loadHighlights(forceRefresh: true);
  }

  /// 更新笔记内容。
  Future<void> updateNote(Note note) async {
    await note_api.upsertNote(note: note);
    await loadHighlights(forceRefresh: true);
  }

  /// 重置所有信号到初始状态。
  void reset() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    highlightsCache.clear();
    highlights.value = AsyncState.data([]);
  }
}
