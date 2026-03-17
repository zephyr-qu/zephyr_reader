import 'package:drift/drift.dart';
import 'package:zephyr_reader/core/database/tables/db_book.dart';
import 'package:zephyr_reader/core/database/tables/db_chapter.dart';

/// 书签表
@DataClassName('DbBookmark')
class DbBookmarks extends Table {
  /// 书签 ID（UUID，主键）
  IntColumn get id => integer().autoIncrement()();

  /// 关联的小说 ID
  IntColumn get bookId =>
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节 ID
  IntColumn get chapterId => integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 书签位置（页码）
  IntColumn get pageIndex => integer()();

  /// 书签标题
  TextColumn get title => text()();

  /// 创建时间戳（Unix 时间戳，秒）
  IntColumn get createdTimestamp => integer()();

  /// 书签备注
  TextColumn get note => text().nullable()();

  /// 书签位置序号
  IntColumn get position => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
