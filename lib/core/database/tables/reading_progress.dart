import 'package:drift/drift.dart';

/// 阅读进度表
@DataClassName('ReadingProgressItem')
class ReadingProgresses extends Table {
  /// 书籍 ID（主键）
  TextColumn get bookId => text()();

  /// 当前章节 ID
  IntColumn get chapterId => integer()();

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
