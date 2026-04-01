import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/bookmark.dart';

import '../../domain/repositories/bookmark_repository.dart';

/// 书签数据仓库实现
@LazySingleton(as: BookmarkRepository)
class BookmarkRepositoryImpl implements BookmarkRepository {
  final AppDatabase _database;

  BookmarkRepositoryImpl(this._database);

  @override
  Future<List<Bookmark>> getBookmarksByBookId(int bookId) async {
    final bookmarks = await _database.getBookmarks(bookId);
    return bookmarks.map((b) => Bookmark.fromDb(b)).toList();
  }

  @override
  Future<List<Bookmark>> getBookmarksByChapterId(int chapterId) async {
    final bookmarks = await _database.getBookmarksByChapterId(chapterId);
    return bookmarks.map((b) => Bookmark.fromDb(b)).toList();
  }

  @override
  Future<Bookmark?> getBookmarkById(int bookmarkId) async {
    final bookmark = await _database.getBookmarkById(bookmarkId);
    return bookmark != null ? Bookmark.fromDb(bookmark) : null;
  }

  @override
  Future<Bookmark?> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    int? position,
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id = await _database.into(_database.dbBookmarks).insert(
      DbBookmarksCompanion.insert(
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: now,
        note: Value(note),
        position: Value(position),
      ),
    );
    return await getBookmarkById(id);
  }

  @override
  Future<bool> deleteBookmark(int bookmarkId) async {
    final result = await (_database.delete(_database.dbBookmarks)
          ..where((tbl) => tbl.id.equals(bookmarkId)))
        .go();
    return result > 0;
  }

  @override
  Future<int> deleteBookmarksByBookId(int bookId) async {
    return await (_database.delete(_database.dbBookmarks)
          ..where((tbl) => tbl.bookId.equals(bookId)))
        .go();
  }
}
