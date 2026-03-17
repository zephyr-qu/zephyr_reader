import 'package:drift/drift.dart';

/// 阅读统计表
@DataClassName('DbReadingStats')
class DbReadingStatss extends Table {
  /// 固定 ID = 1
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// 总阅读时长（秒）
  IntColumn get totalReadingTimeSeconds =>
      integer().withDefault(const Constant(0))();

  /// 总阅读字数
  IntColumn get totalCharactersRead =>
      integer().withDefault(const Constant(0))();

  /// 阅读书籍数量
  IntColumn get booksReadCount => integer().withDefault(const Constant(0))();

  /// 完成阅读书籍数量
  IntColumn get booksCompletedCount =>
      integer().withDefault(const Constant(0))();

  /// 最后阅读日期（YYYY-MM-DD 格式）
  TextColumn get lastReadDate => text().nullable()();

  /// 连续阅读天数
  IntColumn get consecutiveReadingDays =>
      integer().withDefault(const Constant(0))();
}
