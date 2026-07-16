import 'package:zephyr_reader/src/rust/domain/note/models.dart';
import 'package:zephyr_reader/src/rust/domain/vocab/models.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';



/// 书籍搜索结果模型。
class BookSearchItem {
  final Book book;
  final String? snippet;
  final String? chapterTitle;
  BookSearchItem({required this.book, this.snippet, this.chapterTitle});
}

/// 笔记搜索结果模型。
class NoteSearchItem {
  final Note note;
  final Book book;
  NoteSearchItem({required this.note, required this.book});
}

/// 生词搜索结果模型。
class VocabSearchItem {
  final Vocab vocab;
  final String? bookTitle;
  VocabSearchItem({required this.vocab, this.bookTitle});
}

/// 搜索结果聚合模型，包含书籍、笔记和生词三类结果。
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
