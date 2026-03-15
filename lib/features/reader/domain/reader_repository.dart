import 'package:zephyr_reader/core/database/database.dart';

/// 阅读器仓库接口
abstract class ReaderRepository {
  /// 获取章节
  Future<Chapter?> getChapter(int novelId, int chapterIndex);

  /// 获取章节列表
  Future<List<Chapter>> getChapters(int novelId);

  /// 保存阅读历史
  Future<void> saveReadingHistory(
    int novelId,
    int chapterId,
    int position,
    int duration,
  );

  /// 获取阅读历史
  Future<ReadingHistory?> getReadingHistory(int novelId);

  /// 添加书签
  Future<int> addBookmark(
    int novelId,
    int chapterId,
    int position,
    String? note,
  );

  /// 获取书签列表
  Future<List<Bookmark>> getBookmarks(int novelId);

  /// 删除书签
  Future<bool> deleteBookmark(int bookmarkId);

  /// 获取章节内容
  Future<String?> getChapterContent(String contentFile);
}