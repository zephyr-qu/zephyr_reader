/// 基于 Rust 存储的书签仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/bookmark_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: BookmarkRepository)
class RustBookmarkRepository implements BookmarkRepository {
  final _storage = RustStorageService();

  @override
  Future<List<DbBookmark>> getBookmarksByBookId(String bookId) async {
    return _storage.getBookmarks('book_$bookId');
  }

  @override
  Future<List<DbBookmark>> getBookmarksByChapterId(int chapterId) async {
    return [];
  }

  @override
  Future<DbBookmark?> getBookmarkById(String bookmarkId) async {
    return null;
  }

  @override
  Future<DbBookmark?> addBookmark({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
  }) async {
    return _storage.createBookmark(
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      charOffset: pageIndex,
      title: title,
    );
  }

  @override
  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      await _storage.deleteBookmark(bookmarkId);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<int> deleteBookmarksByBookId(String bookId) async {
    final bookmarks = await getBookmarksByBookId(bookId);
    for (final bm in bookmarks) {
      await deleteBookmark(bm.id);
    }
    return bookmarks.length;
  }
}
