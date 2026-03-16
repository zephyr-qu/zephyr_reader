import 'package:drift/drift.dart';

@DataClassName('Book')
class Books extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text()();

  TextColumn get author => text()();

  TextColumn get coverPath => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get filePath => text()();

  TextColumn get fileFormat => text()();

  IntColumn get fileSize => integer().withDefault(const Constant(0))();

  IntColumn get totalChapters => integer().withDefault(const Constant(0))();

  IntColumn get totalCharacters => integer().withDefault(const Constant(0))();

  IntColumn get currentChapterId => integer().nullable()();

  IntColumn get currentPageIndex => integer().withDefault(const Constant(0))();

  IntColumn get totalPages => integer().withDefault(const Constant(0))();

  RealColumn get progress => real().withDefault(const Constant(0.0))();

  TextColumn get status => text().withDefault(const Constant('reading'))();

  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastReadAt => dateTime().nullable()();
}
