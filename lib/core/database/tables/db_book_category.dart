import 'package:drift/drift.dart';

/// 书籍分类表
@DataClassName('DbBookCategory')
class DbBookCategories extends Table {
  /// 分类 ID
  late final id = integer().autoIncrement()();

  /// 分类名称
  late final name = text()();

  /// 分类颜色（16 进制字符串，如 #FF5722）
  late final color = text().withDefault(const Constant('#FF5722'))();

  /// 排序顺序（数字越小越靠前）
  late final sortOrder = integer().withDefault(const Constant(0))();

  /// 是否为系统默认分类（不可删除）
  late final isSystem = boolean().withDefault(const Constant(false))();

  /// 创建时间
  late final createdAt = dateTime().withDefault(currentDateAndTime)();

  /// 更新时间
  late final updatedAt = dateTime().withDefault(currentDateAndTime)();
}
