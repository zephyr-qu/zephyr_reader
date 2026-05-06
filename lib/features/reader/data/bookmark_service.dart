/// 书签服务（基于 Rust）
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/error/app_error.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class BookmarkService {
  final _storage = RustStorageService();

  Future<Result<String>> addBookmark({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
  }) async {
    return Result.guardAsync(() async {
      final bookmark = DbBookmark(
        id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
        bookId: 'book_$bookId',
        chapterIndex: chapterId,
        charOffset: pageIndex,
        title: title,
        createdAt: DateTime.now(),
      );
      await _storage.createBookmark(bookmark);
      return bookmark.id;
    });
  }

  Future<Result<List<DbBookmark>>> getBookmarks(String bookId) async {
    return Result.guardAsync(() async {
      return _storage.getBookmarks('book_$bookId');
    });
  }

  Future<Result<void>> removeBookmark(String bookmarkId) async {
    return Result.guardAsync(() async {
      _storage.deleteBookmark(bookmarkId);
    });
  }

  Future<Result<void>> clearBookmarks(String bookId) async {
    return Result.guardAsync(() async {
      final result = await getBookmarks(bookId);
      if (result.isSuccess) {
        for (final bm in result.value!) {
          await removeBookmark(bm.id);
        }
      }
    });
  }

  Future<Result<List<DbBookmark>>> getAllBookmarks() async {
    return Result.guardAsync(() async {
      final books = _storage.getAllBooks();
      final allBookmarks = <DbBookmark>[];
      for (final book in books) {
        final result = await getBookmarks(book.bookId);
        if (result.isSuccess) {
          allBookmarks.addAll(result.value!);
        }
      }
      return allBookmarks;
    });
  }
}
