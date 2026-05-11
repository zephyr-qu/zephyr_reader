/// Rust 搜索服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as rust;
import 'package:zephyr_reader/src/rust/domain/types.dart';

@LazySingleton()
class RustSearchService {
  Future<void> init() async =>
      await rust.initSearchEngine();

  Future<void> indexChapterContent({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) async =>
      await rust.indexChapterContent(
              bookId: bookId,
              chapterId: chapterId,
              chapterTitle: chapterTitle,
              content: content)
          ;

  Future<List<SearchResult>> searchInBook({
    required String bookId,
    required String query,
    required int limit,
  }) async =>
      rust.searchInBook(bookId: bookId, query: query, limit: limit);

  Future<void> clearAllSearchIndex() async =>
      await rust.clearAllSearchIndex();

  Future<void> deleteBookSearchIndex(String bookId) async =>
      await rust.deleteBookSearchIndex(bookId: bookId);
}
