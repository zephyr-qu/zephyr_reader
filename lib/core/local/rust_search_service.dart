/// Rust 搜索服务
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as rust_core;
import 'package:zephyr_reader/src/rust/api/search.dart' as rust;

@LazySingleton()
class RustSearchService {
  Future<rust_core.ApiResult> init(String dbPath) =>
      rust.initSearchEngine(dbPath: dbPath);

  Future<rust_core.ApiResult> indexChapterContent({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) => rust.indexChapterContent(
    bookId: bookId,
    chapterId: chapterId,
    chapterTitle: chapterTitle,
    content: content,
  );

  rust.ApiResultVecSearchResult searchInBook({
    required String bookId,
    required String query,
    required int limit,
  }) => rust.searchInBook(bookId: bookId, query: query, limit: limit);

  Future<rust_core.ApiResult> clearAllSearchIndex() => rust.clearAllSearchIndex();
}