import 'package:drift/drift.dart';

import 'db_book.dart';
import 'db_chapter.dart';

/// 阅读进度表
@DataClassName('DbReadingProgress')
class DbReadingProgresss extends Table {
  /// 书籍 ID（主键）
  late final bookId = integer().references(
    DbBooks,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// 当前章节 ID
  /// 关联的章节 ID
  late final chapterId = integer().references(
    DbChapters,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// 当前页码
  late final pageIndex = integer()();

  /// 总页数
  late final totalPages = integer()();

  /// 进度百分比（0.0 - 1.0）
  late final progress = real()();

  /// 已阅读时间（秒）
  late final readingTimeSeconds = integer().withDefault(const Constant(0))();

  /// 最后阅读时间戳（Unix 时间戳，秒）
  late final lastReadTimestamp = integer()();

  @override
  Set<Column> get primaryKey => {bookId};
}
