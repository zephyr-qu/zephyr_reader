import 'package:drift/drift.dart';
import 'package:zephyr_reader/core/database/tables/db_book.dart';

/// 章节表
@DataClassName('DbChapter')
class DbChapters extends Table {
  late final id = integer().autoIncrement()();

  /// 关联的小说ID
  late final bookId = integer().references(
    DbBooks,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// 章节标题
  late final title = text()();

  /// 章节内容文件路径
  late final contentFile = text()();

  /// 章节索引（从1开始）
  late final chapterIndex = integer()();

  /// 字数
  late final wordCount = integer().withDefault(const Constant(0))();

  /// 缓存时间
  late final cachedAt = dateTime().withDefault(currentDateAndTime)();
}
