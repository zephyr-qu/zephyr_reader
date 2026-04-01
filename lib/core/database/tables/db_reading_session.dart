import 'package:drift/drift.dart';

import 'db_book.dart';
import 'db_chapter.dart';

/// 阅读会话记录表
@DataClassName('DbReadingSession')
class DbReadingSessions extends Table {
  /// 会话 ID（UUID）
  late final id = integer().autoIncrement()();

  /// 书籍 ID
  late final bookId =
      integer().references(DbBooks, #id, onDelete: KeyAction.cascade)();

  /// 关联的章节 ID
  late final chapterId =
      integer().references(DbChapters, #id, onDelete: KeyAction.cascade)();

  /// 开始时间戳（Unix 时间戳，秒）
  late final startTimestamp = integer()();

  /// 结束时间戳（Unix 时间戳，秒）
  late final endTimestamp = integer()();

  /// 阅读时长（秒）
  late final durationSeconds = integer()();

  /// 阅读字数
  late final charactersRead = integer().withDefault(const Constant(0))();
}
