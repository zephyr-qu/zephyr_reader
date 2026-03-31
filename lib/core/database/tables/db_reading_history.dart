import 'package:drift/drift.dart';

import 'db_book.dart';
import 'db_chapter.dart';

/// 阅读历史表
@DataClassName('DbReadingHistory')
class DbReadingHistorys extends Table {
  late final id = integer().autoIncrement()();

  /// 关联的小说ID
  late final bookId =
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节ID
  late final chapterId =
      integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 阅读位置（字符偏移量）
  late final position = integer()();

  /// 阅读时间
   late final readTime = dateTime().withDefault(currentDateAndTime)();

  /// 阅读时长（秒）
  late final duration = integer().withDefault(const Constant(0))();
}
