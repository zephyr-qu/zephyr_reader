import 'package:drift/drift.dart';

import 'db_book.dart';
import 'db_chapter.dart';

/// 阅读会话记录表
@DataClassName('DbReadingSession')
class DbReadingSessions extends Table {
  /// 会话 ID（UUID）
  IntColumn get id => integer().autoIncrement()();

  /// 书籍 ID
   IntColumn get bookId =>
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

   /// 关联的章节 ID
  IntColumn get chapterId =>
      integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 开始时间戳（Unix 时间戳，秒）
  IntColumn get startTimestamp => integer()();

  /// 结束时间戳（Unix 时间戳，秒）
  IntColumn get endTimestamp => integer()();

  /// 阅读时长（秒）
  IntColumn get durationSeconds => integer()();

  /// 阅读字数
  IntColumn get charactersRead => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
