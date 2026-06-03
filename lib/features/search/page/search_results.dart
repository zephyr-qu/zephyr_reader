import 'package:zephyr_reader/src/rust/storage/models.dart';

// ──────────────────────── Models ────────────────────────

class BookSearchItem {
  final Book book;
  final String? snippet;
  final String? chapterTitle;
  BookSearchItem({required this.book, this.snippet, this.chapterTitle});
}

class NoteSearchItem {
  final Note note;
  final Book book;
  NoteSearchItem({required this.note, required this.book});
}

class VocabSearchItem {
  final Vocab vocab;
  final String? bookTitle;
  VocabSearchItem({required this.vocab, this.bookTitle});
}

class SearchResults {
  final List<BookSearchItem> books;
  final List<NoteSearchItem> notes;
  final List<VocabSearchItem> vocab;
  final int durationMs;
  SearchResults({
    required this.books,
    required this.notes,
    required this.vocab,
    required this.durationMs,
  });
  int get totalCount => books.length + notes.length + vocab.length;
}