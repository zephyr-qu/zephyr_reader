import 'package:drift/drift.dart';

import 'db_book.dart';
import 'db_chapter.dart';


/// 阅读进度表
@DataClassName('DbReadingProgress')
class DbReadingProgresss extends Table {
  /// 书籍 ID（主键）
  IntColumn get bookId =>
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

  /// 当前章节 ID
   /// 关联的章节 ID
  IntColumn get chapterId =>
      integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 当前页码
  IntColumn get pageIndex => integer()();

  /// 总页数
  IntColumn get totalPages => integer()();

  /// 进度百分比（0.0 - 1.0）
  RealColumn get progress => real()();

  /// 已阅读时间（秒）
  IntColumn get readingTimeSeconds =>
      integer().withDefault(const Constant(0))();

  /// 最后阅读时间戳（Unix 时间戳，秒）
  IntColumn get lastReadTimestamp => integer()();

  @override
  Set<Column> get primaryKey => {bookId};
}
