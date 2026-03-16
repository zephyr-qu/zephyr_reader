import 'package:zephyr_reader/core/database/database.dart';

/// 阅读器仓库接口
abstract class ReaderRepository {
  /// 获取章节
  Future<Chapter?> getChapter(int bookId, int chapterIndex);

  /// 获取章节列表
  Future<List<Chapter>> getChapters(int bookId);

  /// 保存阅读历史
  Future<void> saveReadingHistory(
    int bookId,
    int chapterId,
    int position,
    int duration,
  );

  /// 获取阅读历史
  Future<ReadingHistory?> getReadingHistory(int bookId);

  /// 添加书签
  Future<int> addBookmark(
    int bookId,
    int chapterId,
    int position,
    String? note,
  );

  /// 获取书签列表
  Future<List<Bookmark>> getBookmarks(int bookId);

  /// 删除书签
  Future<bool> deleteBookmark(String bookmarkId);

  /// 获取章节内容
  Future<String?> getChapterContent(String contentFile);
}
