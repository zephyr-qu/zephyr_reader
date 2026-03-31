import 'package:drift/drift.dart';
import 'package:zephyr_reader/core/database/tables/db_book.dart';
import 'package:zephyr_reader/core/database/tables/db_chapter.dart';

/// 书签表
@DataClassName('DbBookmark')
class DbBookmarks extends Table {
  /// 书签 ID（UUID，主键）
  late final id = integer().autoIncrement()();

  /// 关联的小说 ID
  late final bookId =
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节 ID
  late final chapterId =
      integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 书签位置（页码）
  late final pageIndex = integer()();

  /// 书签标题
  late final title = text()();

  /// 创建时间戳（Unix 时间戳，秒）
  late final createdTimestamp = integer()();

  /// 书签备注
  late final note = text().nullable()();

  /// 书签位置序号
  late final position = integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
