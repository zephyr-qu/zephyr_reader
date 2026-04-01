/// 书签服务（基于 Drift）
///
/// 功能：
/// - 添加、删除书签
/// - 获取书籍的所有书签
/// - 获取所有书签
library;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';

/// 书签服务
@injectable
class BookmarkService {

  BookmarkService(this._db);
  final AppDatabase _db;

  /// 添加书签
  Future<void> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    String? note,
  }) async {
    try {
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

      return;
    } catch (e) {
      debugPrint('BookmarkService.addBookmark error: $e');
      rethrow;
    }
  }

  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarks(int bookId) async {
    try {
      final bookmarks = await _db.getBookmarks(bookId);
      return bookmarks.map((e) => Bookmark.fromDb(e)).toList();
    } catch (e) {
      debugPrint('BookmarkService.getBookmarks error: $e');
      return [];
    }
  }

  /// 删除书签
  Future<void> removeBookmark(int bookmarkId) async {
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
      final bookmarks = await _db.getAllBookmarks();
      return bookmarks.map((bookmark) => Bookmark.fromDb(bookmark)).toList();
    } catch (e) {
      debugPrint('BookmarkService.getAllBookmarks error: $e');
      return [];
    }
  }
}
