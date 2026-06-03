import 'package:signals_flutter/signals_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class BookDetailViewModel {
  final String bookId;

  final book = signal<Book?>(null);
  final progress = signal<ReadingProgress?>(null);
  final noteStats = signal<NoteStats?>(null);
  final chapters = signal<List<Chapter>>([]);
  final categories = signal<List<Category>>([]);
  final sessions = signal<List<ReadingSession>>([]);
  final vocabList = signal<List<Vocab>>([]);
  final showAllChapters = signal(false);
  final loading = signal(true);
  final error = signal<String?>(null);

  BookDetailViewModel({required this.bookId}) {
    loadData();
  }

  Future<void> loadData() async {
    loading.value = true;
    error.value = null;
    try {
      final detail = await book_api.getBookDetail(bookId: bookId);
      book.value = detail.book;
      progress.value = detail.progress;
      noteStats.value = detail.noteStats;
      chapters.value = detail.chapters;
      categories.value = detail.categories;
      sessions.value = detail.sessions;
      vocabList.value = detail.vocabList;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> deleteBook() async {
    await book_api.deleteBook(bookId: bookId);
  }

  void toggleShowAllChapters() {
    showAllChapters.value = !showAllChapters.value;
  }

  // book_detail_view_model.dart 添加
  void dispose() {
    book.dispose();
    progress.dispose();
    noteStats.dispose();
    chapters.dispose();
    categories.dispose();
    sessions.dispose();
    vocabList.dispose();
    showAllChapters.dispose();
    loading.dispose();
    error.dispose();
  }
}
