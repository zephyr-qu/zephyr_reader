import 'package:drift/drift.dart';

/// 每日阅读记录表
@DataClassName('DbDailyReadingRecord')
class DbDailyReadingRecords extends Table {
  /// 日期（YYYY-MM-DD 格式，主键）
  TextColumn get date => text()();

  /// 阅读时长（秒）
  IntColumn get readingTimeSeconds =>
      integer().withDefault(const Constant(0))();

  /// 阅读字数
  IntColumn get charactersRead => integer().withDefault(const Constant(0))();

  /// 阅读章节数
  IntColumn get chaptersRead => integer().withDefault(const Constant(0))();

  /// 阅读页数
  IntColumn get pagesRead => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {date};
}
