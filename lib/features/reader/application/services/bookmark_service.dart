/// 书签服务（基于 Drift）
///
/// 功能：
/// - 添加、删除书签
/// - 获取书籍的所有书签
/// - 获取所有书签
library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:zephyr_reader/core/database/database.dart';

const _uuid = Uuid();

/// 书签服务
class BookmarkService {
  final AppDatabase _db;

  BookmarkService(this._db);

  /// 添加书签
  Future<Bookmark> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    String? note,
  }) async {
    try {
      final bookmarkId = _uuid.v4();
      final createdTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _db.addBookmark(
        bookmarkId: bookmarkId,
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: createdTimestamp,
        note: note,
      );

      return Bookmark(
        bookmarkId: bookmarkId,
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: createdTimestamp,
        note: note,
      );
    } catch (e) {
      debugPrint('BookmarkService.addBookmark error: $e');
      rethrow;
    }
  }

  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarks(int bookId) async {
    try {
      return await _db.getBookmarks(bookId);
    } catch (e) {
      debugPrint('BookmarkService.getBookmarks error: $e');
      return [];
    }
  }

  /// 删除书签
  Future<void> removeBookmark(String bookmarkId) async {
    try {
      await _db.removeBookmark(bookmarkId);
    } catch (e) {
      debugPrint('BookmarkService.removeBookmark error: $e');
      rethrow;
    }
  }

  /// 清除书籍的所有书签
  Future<void> clearBookmarks(int bookId) async {
    try {
      await _db.clearBookmarks(bookId);
    } catch (e) {
      debugPrint('BookmarkService.clearBookmarks error: $e');
    }
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() async {
    try {
      return await _db.getAllBookmarks();
    } catch (e) {
      debugPrint('BookmarkService.getAllBookmarks error: $e');
      return [];
    }
  }
}
