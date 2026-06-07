import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书籍详情 ViewModel。
///
/// 加载并管理书籍的详细信息、阅读进度、笔记统计、章节列表等。
class BookDetailViewModel {
  BookDetailViewModel({required this.bookId});

  final book = asyncSignal<Book>(AsyncState.loading());
  final progress = asyncSignal<ReadingProgress?>(AsyncState.loading());
  final noteStats = asyncSignal<NoteStats?>(AsyncState.loading());
  final chapters = asyncSignal<List<Chapter>>(AsyncState.loading());
  final categories = asyncSignal<List<Category>>(AsyncState.loading());
  final sessionCount = signal<int>(0);
  final vocabCount = signal<int>(0);

  final String bookId;

  /// 从 Rust 侧加载书籍详情，包括进度、笔记统计、章节、分类、阅读会话和生词列表。
  Future<void> loadData() async {
    try {
      final detail = await book_api.getBookDetail(bookId: bookId);
      batch(() {
        book.value = AsyncState.data(detail.book);
        progress.value = AsyncState.data(detail.progress);
        noteStats.value = AsyncState.data(detail.noteStats);
        chapters.value = AsyncState.data(detail.chapters);
        categories.value = AsyncState.data(detail.categories);
        sessionCount.value = detail.sessionCount;
        vocabCount.value = detail.vocabCount;
      });
    } catch (e) {
      book.value = AsyncState.error(e);
      progress.value = AsyncState.error(e);
      noteStats.value = AsyncState.error(e);
      chapters.value = AsyncState.error(e);
      categories.value = AsyncState.error(e);
      sessionCount.value = 0;
      vocabCount.value = 0;
    }
  }

  /// 删除本书及封面文件。
  Future<void> deleteBook() async {
    await book_api.deleteBook(
      bookId: bookId,
      coversDir: AppConfig.instance.coverDir,
    );
  }

  /// 释放所有 signal 资源。
  void dispose() {
    book.dispose();
    progress.dispose();
    categories.dispose();
    noteStats.dispose();
    chapters.dispose();
    sessionCount.dispose();
    vocabCount.dispose();
  }
}
