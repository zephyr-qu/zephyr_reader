/// 书签服务（基于 Drift）
///
/// 功能：
/// - 添加、删除书签
/// - 获取书籍的所有书签
/// - 获取所有书签
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/error/app_error.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';

/// 书签服务
@injectable
class BookmarkService {
  BookmarkService(this._db);
  final AppDatabase _db;

  /// 添加书签
  Future<Result<int>> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    String? note,
  }) async {
    return Result.guardAsync(() async {
      final createdTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _db.addBookmark(
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: createdTimestamp,
        note: note,
        position: 0,
      );

      return createdTimestamp.toInt();
    });
  }

  /// 获取书籍的所有书签
  Future<Result<List<Bookmark>>> getBookmarks(int bookId) async {
    return Result.guardAsync(() async {
      final bookmarks = await _db.getBookmarks(bookId);
      return bookmarks.map((e) => Bookmark.fromDb(e)).toList();
    });
  }

  /// 删除书签
  Future<Result<void>> removeBookmark(int bookmarkId) async {
    return Result.guardAsync(() async {
      await _db.removeBookmark(bookmarkId);
    });
  }

  /// 清除书籍的所有书签
  Future<Result<void>> clearBookmarks(int bookId) async {
    return Result.guardAsync(() async {
      await _db.clearBookmarks(bookId);
    });
  }

  /// 获取所有书签
  Future<Result<List<Bookmark>>> getAllBookmarks() async {
    return Result.guardAsync(() async {
      final bookmarks = await _db.getAllBookmarks();
      return bookmarks.map((bookmark) => Bookmark.fromDb(bookmark)).toList();
    });
  }
}
