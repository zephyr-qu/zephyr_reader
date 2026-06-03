import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../domain/services/highlight_painter.dart';

/// 划词批注控制器
///
/// 管理选中文本、高亮和笔记的增删查，直接调用 Rust API。
@injectable
class AnnotationController {
  AnnotationController();

  // ==================== 信号 ====================

  /// 当前选中的文本
  final selectedText = signal<String>('');

  /// 当前选中的起始偏移
  final selectionStart = signal<int>(0);

  /// 当前选中的结束偏移
  final selectionEnd = signal<int>(0);

  /// 是否显示批注工具栏
  final showSelectionToolbar = signal<bool>(false);

  /// 当前章节的高亮列表
  final highlights = signal<List<Note>>([]);

  // ==================== 加载 ====================

  /// 加载当前章节的高亮和批注
  Future<void> loadHighlights(String bookId, int chapterIndex) async {
    try {
      highlights.value = await note_api.listNotesInChapter(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );
    } catch (_) {
      highlights.value = [];
    }
    HighlightPainter.invalidateCache();
  }

  // ==================== 选择管理 ====================

  /// 更新选中文本
  void updateSelection(String text, int start, int end) {
    if (text.isEmpty || start == end) {
      clearSelection();
      return;
    }
    selectedText.value = text;
    selectionStart.value = start;
    selectionEnd.value = end;
    showSelectionToolbar.value = true;
  }

  /// 清除选中
  void clearSelection() {
    selectedText.value = '';
    selectionStart.value = 0;
    selectionEnd.value = 0;
    showSelectionToolbar.value = false;
  }

  // ==================== 高亮 & 笔记 CRUD ====================

  /// 创建高亮（Rust API 自动生成 UUID）
  Future<Note> createHighlight({
    required String bookId,
    required int chapterIndex,
    required int selectionStart,
    required int selectionEnd,
    required String selectedText,
  }) async {
    return note_api.createHighlight(
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: selectionStart,
      length: selectionEnd - selectionStart,
      selectedText: selectedText,
      color: 0xFFFFEB3B,
    );
  }

  /// 创建批注（Rust API 自动生成 UUID）
  Future<Note> createAnnotation({
    required String bookId,
    required int chapterIndex,
    required int selectionStart,
    required int selectionEnd,
    required String selectedText,
    required String annotationContent,
  }) async {
    return note_api.createAnnotation(
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: selectionStart,
      content: annotationContent,
      selectedText: selectedText,
    );
  }

  /// 删除高亮/笔记
  Future<void> deleteNote(String noteId) async {
    await note_api.deleteNote(noteId: noteId);
  }

  /// 更新笔记内容（upsert）
  Future<void> updateNote(Note note) async {
    await note_api.upsertNote(note: note);
  }

  void dispose() {
    selectedText.dispose();
    selectionStart.dispose();
    selectionEnd.dispose();
    showSelectionToolbar.dispose();
    highlights.dispose();
  }
}
