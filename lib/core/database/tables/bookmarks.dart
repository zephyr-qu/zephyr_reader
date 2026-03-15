import 'package:drift/drift.dart';
import 'novels.dart';
import 'chapters.dart';

/// 书签表
@DataClassName('Bookmark')
class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联的小说ID
  IntColumn get novelId => integer().references(Novels, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节ID
  IntColumn get chapterId => integer().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// 书签位置（字符偏移量）
  IntColumn get position => integer()();

  /// 书签备注
  TextColumn get note => text().nullable()();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}