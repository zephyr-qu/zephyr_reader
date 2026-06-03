import 'package:signals_flutter/signals_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/api/data/chapter.dart' as chapter_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/data/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
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
      final results = await Future.wait([
        book_api.getBook(bookId: bookId),
        progress_api.getProgress(bookId: bookId),
        note_api.getNoteStats(bookId: bookId),
        chapter_api.listChaptersByBook(bookId: bookId),
        category_api.listCategoriesByBook(bookId: bookId),
        session_api.listSessionsByBook(
          bookId: bookId,
          limit: BigInt.from(10000),
        ),
        vocab_api.listVocabularyByStatus(bookId: bookId),
      ]);
      book.value = results[0] as Book?;
      progress.value = results[1] as ReadingProgress?;
      noteStats.value = results[2] as NoteStats?;
      chapters.value = results[3] as List<Chapter>;
      categories.value = results[4] as List<Category>;
      sessions.value = results[5] as List<ReadingSession>;
      vocabList.value = results[6] as List<Vocab>;
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
