import 'package:drift/drift.dart';
import 'novels.dart';

/// 章节表
@DataClassName('Chapter')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联的小说ID
  IntColumn get novelId => integer().references(Novels, #id, onDelete: KeyAction.cascade)();

  /// 章节标题
  TextColumn get title => text()();

  /// 章节内容文件路径
  TextColumn get contentFile => text()();

  /// 章节索引（从1开始）
  IntColumn get chapterIndex => integer()();

  /// 字数
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  /// 缓存时间
  DateTimeColumn get cachedAt => dateTime().withDefault(currentDateAndTime)();
}