import 'package:drift/drift.dart';

/// 每日阅读记录表
@DataClassName('DbDailyReadingRecord')
class DbDailyReadingRecords extends Table {
  /// 日期（YYYY-MM-DD 格式，主键）
  late final date = text()();

  /// 阅读时长（秒）
  late final readingTimeSeconds =
      integer().withDefault(const Constant(0))();

  /// 阅读字数
  late final charactersRead = integer().withDefault(const Constant(0))();

  /// 阅读章节数
  late final chaptersRead = integer().withDefault(const Constant(0))();

  /// 阅读页数
  late final pagesRead = integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {date};
}
