import 'package:drift/drift.dart';

@DataClassName('DbBook')
class DbBooks extends Table {
  /// 书籍 ID（UUID）
  late final id = integer().autoIncrement()();

  late final title = text()();

  late final author = text()();

  late final coverPath = text().nullable()();

  late final description = text().nullable()();

  late final filePath = text()();

  late final fileType = text()();

  late final fileSize = integer().withDefault(const Constant(0))();

  late final totalChapters = integer().withDefault(const Constant(0))();

  late final totalCharacters = integer().withDefault(const Constant(0))();

  late final currentChapterId = integer().nullable()();

  late final currentPageIndex = integer().withDefault(const Constant(0))();

  late final totalPages = integer().withDefault(const Constant(0))();

  late final progress = real().withDefault(const Constant(0.0))();

  late final status = text().withDefault(const Constant('reading'))();

  late final isPinned = boolean().withDefault(const Constant(false))();

  /// 分类 ID 列表（JSON 格式存储）
  late final categoryIds = text().withDefault(const Constant('[]'))();

  late final createdAt = dateTime().withDefault(currentDateAndTime)();

  late final updatedAt = dateTime().withDefault(currentDateAndTime)();

  late final lastReadAt = dateTime().nullable()();
}
