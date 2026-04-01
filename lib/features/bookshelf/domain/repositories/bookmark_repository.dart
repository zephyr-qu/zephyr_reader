import 'package:zephyr_reader/domain/models/bookmark.dart';

/// 书签数据仓库接口
abstract class BookmarkRepository {
  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarksByBookId(int bookId);

  /// 获取章节的所有书签
  Future<List<Bookmark>> getBookmarksByChapterId(int chapterId);

  /// 根据 ID 获取书签
  Future<Bookmark?> getBookmarkById(int bookmarkId);

  /// 添加书签
  Future<Bookmark?> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    int? position,
    String? note,
  });

  /// 删除书签
  Future<bool> deleteBookmark(int bookmarkId);

  /// 删除书籍的所有书签
  Future<int> deleteBookmarksByBookId(int bookId);
}
