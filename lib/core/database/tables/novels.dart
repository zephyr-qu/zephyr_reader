import 'package:drift/drift.dart';

/// 小说表
@DataClassName('Novel')
class Novels extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 书籍标题
  TextColumn get title => text()();

  /// 作者
  TextColumn get author => text()();

  /// 封面图片路径
  TextColumn get coverPath => text().nullable()();

  /// 描述
  TextColumn get description => text().nullable()();

  /// 总章节数
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();

  /// 状态：reading-阅读中, completed-已完结, dropped-已弃坑
  TextColumn get status => text().withDefault(const Constant('reading'))();

  /// 创建时间
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
