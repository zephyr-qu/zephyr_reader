import 'package:drift/drift.dart';

import 'books.dart';
import 'chapters.dart';

/// 阅读历史表
@DataClassName('ReadingHistory')
class ReadingHistories extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 关联的小说ID
  IntColumn get bookId =>
      integer().references(Books, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节ID
  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();

  /// 阅读位置（字符偏移量）
  IntColumn get position => integer()();

  /// 阅读时间
  DateTimeColumn get readTime => dateTime().withDefault(currentDateAndTime)();

  /// 阅读时长（秒）
  IntColumn get duration => integer().withDefault(const Constant(0))();
}
