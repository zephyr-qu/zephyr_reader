import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节数据仓库接口
abstract class ChapterRepository {
  /// 根据书籍 ID 获取所有章节
  Future<List<Chapter>> getChaptersByBookId(int bookId);

  /// 根据书籍 ID 和章节索引获取章节
  Future<Chapter?> getChapterByIndex(int bookId, int chapterIndex);

  /// 根据章节 ID 获取章节
  Future<Chapter?> getChapterById(String chapterId);

  /// 批量插入章节
  Future<int> insertChapters(List<Chapter> chapters);

  /// 删除书籍的所有章节
  Future<int> deleteChaptersByBookId(int bookId);
}
