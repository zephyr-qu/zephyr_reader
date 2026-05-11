import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书签数据仓库接口
abstract class BookmarkRepository {
  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarksByBookId(String bookId);

  /// 获取章节的所有书签
  Future<List<Bookmark>> getBookmarksByChapterId(int chapterId);

  /// 根据 ID 获取书签
  Future<Bookmark?> getBookmarkById(String bookmarkId);

  /// 添加书签
  Future<Bookmark?> addBookmark({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
  });

  /// 删除书签
  Future<bool> deleteBookmark(String bookmarkId);

  /// 删除书籍的所有书签
  Future<int> deleteBookmarksByBookId(String bookId);
}
