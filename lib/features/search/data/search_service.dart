import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';

class SearchResult {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final int totalChapters;
  final String source;

  SearchResult({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    required this.totalChapters,
    required this.source,
  });
}

@LazySingleton()
class SearchRepository {
  final RustStorageService _storage;

  SearchRepository(this._storage);

  Future<List<SearchResult>> search(
    String keyword, {
    int page = 1,
    int pageSize = 20,
  }) async {
    if (keyword.trim().isEmpty) return [];
    try {
      final books = await _storage.searchBooks(keyword.trim());
      return books
          .map(
            (b) => SearchResult(
              id: b.bookId,
              title: b.title,
              author: b.author ?? '',
              coverUrl: b.coverPath,
              description: b.description,
              totalChapters: b.chapterCount,
              source: b.format.name,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<SearchResult?> getDetail(String id) async {
    try {
      final book = await _storage.getBook(id);
      if (book == null) return null;
      return SearchResult(
        id: book.bookId,
        title: book.title,
        author: book.author ?? '',
        coverUrl: book.coverPath,
        description: book.description,
        totalChapters: book.chapterCount,
        source: book.format.name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getChapters(String id) async {
    try {
      final chapters = await _storage.getChaptersByBook(id);
      return chapters.map((c) => c.title).toList();
    } catch (_) {
      return [];
    }
  }
}
