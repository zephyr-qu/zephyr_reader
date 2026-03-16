import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/novels.dart';
import 'tables/chapters.dart';
import 'tables/bookmarks.dart';
import 'tables/reading_history.dart';

part 'database.g.dart';

/// 应用数据库
@DriftDatabase(tables: [Novels, Chapters, Bookmarks, ReadingHistories])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 未来版本升级时的迁移逻辑
      },
    );
  }

  /// 查询所有小说
  Future<List<Novel>> getAllNovels() => select(novels).get();

  /// 根据ID查询小说
  Future<Novel?> getNovelById(int id) =>
      (select(novels)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// 搜索小说
  Future<List<Novel>> searchNovels(String keyword) {
    return (select(novels)..where(
          (tbl) => tbl.title.contains(keyword) | tbl.author.contains(keyword),
        ))
        .get();
  }

  /// 查询小说的所有章节
  Future<List<Chapter>> getChaptersByNovelId(int novelId) {
    return (select(chapters)
          ..where((tbl) => tbl.novelId.equals(novelId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.chapterIndex)]))
        .get();
  }

  /// 根据小说ID和章节索引查询章节
  Future<Chapter?> getChapter(int novelId, int chapterIndex) {
    return (select(chapters)..where(
          (tbl) =>
              tbl.novelId.equals(novelId) &
              tbl.chapterIndex.equals(chapterIndex),
        ))
        .getSingleOrNull();
  }

  /// 获取阅读历史
  Future<List<ReadingHistory>> getReadingHistory() {
    return (select(
      readingHistories,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.readTime)])).get();
  }

  /// 获取小说的阅读历史
  Future<ReadingHistory?> getNovelReadingHistory(int novelId) {
    return (select(
      readingHistories,
    )..where((tbl) => tbl.novelId.equals(novelId))).getSingleOrNull();
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() => select(bookmarks).get();

  /// 获取小说的所有书签
  Future<List<Bookmark>> getBookmarksByNovelId(int novelId) {
    return (select(bookmarks)
          ..where((tbl) => tbl.novelId.equals(novelId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }
}

/// 创建数据库实例
Future<AppDatabase> openDatabase() async {
  final dbDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbDir.path, 'zephyr_reader.db'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}
