import 'package:drift/drift.dart';

/// 阅读会话记录表
@DataClassName('ReadingSessionItem')
class ReadingSessions extends Table {
  /// 会话 ID（UUID）
  TextColumn get sessionId => text()();

  /// 书籍 ID
  TextColumn get bookId => text()();

  /// 章节 ID
  IntColumn get chapterId => integer()();

  /// 开始时间戳（Unix 时间戳，秒）
  IntColumn get startTimestamp => integer()();

  /// 结束时间戳（Unix 时间戳，秒）
  IntColumn get endTimestamp => integer()();

  /// 阅读时长（秒）
  IntColumn get durationSeconds => integer()();

  /// 阅读字数
  IntColumn get charactersRead => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId};
}
