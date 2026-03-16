import 'package:drift/drift.dart';

/// 排版缓存表
@DataClassName('LayoutCacheItem')
class LayoutCaches extends Table {
  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 书籍 ID
  TextColumn get bookId => text()();

  /// 章节 ID
  IntColumn get chapterId => integer()();

  /// 排版配置哈希
  TextColumn get configHash => text()();

  /// 页面偏移量列表（JSON 格式）
  TextColumn get pageOffsets => text()();

  /// 总页数
  IntColumn get totalPages => integer()();

  /// 创建时间戳（Unix 时间戳，秒）
  IntColumn get createdAt => integer()();

  /// 唯一索引：book_id + chapter_id + config_hash
  @override
  List<Set<Column>> get uniqueKeys => [
    {bookId, chapterId, configHash},
  ];
}
