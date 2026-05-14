/// 基于 Rust 存储的书签仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable()
class BookmarkRepository {
  final RustStorageService _storage;
  BookmarkRepository(this._storage);

  
  Future<List<Bookmark>> getBookmarksByBookId(String bookId) async {
    return _storage.getBookmarks('book_$bookId');
  }

  Future<List<Bookmark>> getBookmarksByChapterId(int chapterId) async {
    // 需要 bookId 参数才能查 Rust API；上层应在调用前用 getBookmarksByBookId 再过滤
    return [];
  }

  Future<Bookmark?> getBookmarkById(String bookmarkId) async {
    try {
      return _storage.getBookmark(bookmarkId);
    } catch (_) {
      return null;
    }
  }

  Future<Bookmark?> addBookmark({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
  }) async {
    final bookmark = Bookmark(
      id: 'bookmark_${DateTime.now().millisecondsSinceEpoch}',
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      charOffset: pageIndex,
      title: title,
      createdAt: DateTime.now(),
    );
    await _storage.createBookmark(bookmark);
    return bookmark;
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      await _storage.deleteBookmark(bookmarkId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> deleteBookmarksByBookId(String bookId) async {
    final bookmarks = await getBookmarksByBookId(bookId);
    for (final bm in bookmarks) {
      await deleteBookmark(bm.id);
    }
    return bookmarks.length;
  }
}
