import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/database/tables/db_book.dart';
import 'package:zephyr_reader/core/database/tables/db_bookmark.dart'
    show DbBookmarks;
import 'package:zephyr_reader/core/database/tables/db_chapter.dart';
import 'package:zephyr_reader/core/database/tables/db_daily_reading_record.dart';
import 'package:zephyr_reader/core/database/tables/db_layout_cache.dart';
import 'package:zephyr_reader/core/database/tables/db_reading_history.dart';
import 'package:zephyr_reader/core/database/tables/db_reading_progress.dart';
import 'package:zephyr_reader/core/database/tables/db_reading_session.dart';
import 'package:zephyr_reader/core/database/tables/db_reading_stats.dart';

part 'database.g.dart';

/// 应用数据库
@DriftDatabase(
  tables: [
    DbBooks,
    DbChapters,
    DbBookmarks,
    DbReadingHistorys,
    DbReadingProgresss,
    DbLayoutCaches,
    DbReadingStatss,
    DbDailyReadingRecords,
    DbReadingSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  /// 查询所有小说
  Future<List<DbBook>> getAllBooks() => select(dbBooks).get();

  /// 插入小说
  Future<int> insertBook(DbBook book) async {
    return into(dbBooks).insert(
      book,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 批量插入小说
  Future<void> insertBookList(List<DbBook> list) async {
    await transaction(() async {
      for (final item in list) {
        await into(dbBooks).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// 根据 ID 查询小说
  Future<DbBook?> getBookById(int id) =>
      (select(dbBooks)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// 搜索小说
  Future<List<DbBook>> searchBooks(String keyword) {
    return (select(dbBooks)..where(
          (tbl) => tbl.title.contains(keyword) | tbl.author.contains(keyword),
        ))
        .get();
  }

  /// 查询小说的所有章节
  Future<List<DbChapter>> getChaptersByBookId(int bookId) {
    return (select(dbChapters)
          ..where((tbl) => tbl.bookId.equals(bookId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.chapterIndex)]))
        .get();
  }

  /// 根据小说 ID 和章节索引查询章节
  Future<DbChapter?> getChapter(int bookId, int chapterIndex) {
    return (select(dbChapters)..where(
          (tbl) =>
              tbl.bookId.equals(bookId) & tbl.chapterIndex.equals(chapterIndex),
        ))
        .getSingleOrNull();
  }

  /// 根据章节 ID 查询章节
  Future<DbChapter?> getChapterById(int chapterId) {
    return (select(dbChapters)..where((tbl) => tbl.id.equals(chapterId)))
        .getSingleOrNull();
  }

  /// 获取阅读历史
  Future<List<DbReadingHistory>> getReadingHistory() {
    return (select(
      dbReadingHistorys,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.readTime)])).get();
  }

  /// 获取小说的阅读历史
  Future<DbReadingHistory?> getBookReadingHistory(int bookId) {
    return (select(
      dbReadingHistorys,
    )..where((tbl) => tbl.bookId.equals(bookId))).getSingleOrNull();
  }

  // ==================== 阅读进度管理 ====================

  /// 更新阅读进度
  Future<void> updateReadingProgress({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final progress = pageIndex / totalPages;

    await into(dbReadingProgresss).insert(
      DbReadingProgresssCompanion.insert(
        bookId: Value(bookId),
        chapterId: chapterId,
        pageIndex: pageIndex,
        totalPages: totalPages,
        progress: progress,
        readingTimeSeconds: Value(readingTimeSeconds),
        lastReadTimestamp: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取阅读进度
  Future<DbReadingProgress?> getReadingProgress(int bookId) {
    return (select(
      dbReadingProgresss,
    )..where((tbl) => tbl.bookId.equals(bookId))).getSingleOrNull();
  }

  /// 清除阅读进度
  Future<void> clearReadingProgress(int bookId) {
    return (delete(
      dbReadingProgresss,
    )..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 获取所有阅读进度
  Future<List<DbReadingProgress>> getAllReadingProgress() {
    return (select(
      dbReadingProgresss,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.lastReadTimestamp)])).get();
  }

  /// 插入阅读进度
  Future<int> insertReadingProgress(DbReadingProgress progress) async {
    return into(dbReadingProgresss).insert(
      progress,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 批量插入阅读进度
  Future<void> insertReadingProgressList(List<DbReadingProgress> list) async {
    await transaction(() async {
      for (final item in list) {
        await into(dbReadingProgresss).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ==================== 书签管理 ====================

  /// 添加书签
  Future<void> addBookmark({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    required int position,
    required int createdTimestamp,
    String? note,
  }) async {
    await into(dbBookmarks).insert(
      DbBookmarksCompanion.insert(
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: createdTimestamp,
        note: Value(note),
        position: Value(position),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取书籍的所有书签
  Future<List<DbBookmark>> getBookmarks(int bookId) {
    return (select(
      dbBookmarks,
    )..where((tbl) => tbl.bookId.equals(bookId))).get();
  }

  /// 根据 ID 获取书签
  Future<DbBookmark?> getBookmarkById(int bookmarkId) {
    return (select(dbBookmarks)..where((tbl) => tbl.id.equals(bookmarkId)))
        .getSingleOrNull();
  }

  /// 根据章节 ID 获取书签
  Future<List<DbBookmark>> getBookmarksByChapterId(int chapterId) {
    return (select(dbBookmarks)..where((tbl) => tbl.chapterId.equals(chapterId)))
        .get();
  }

  /// 删除书签
  Future<void> removeBookmark(int bookmarkId) {
    return (delete(
      dbBookmarks,
    )..where((tbl) => tbl.id.equals(bookmarkId))).go();
  }

  /// 清除书籍的所有书签
  Future<void> clearBookmarks(int bookId) {
    return (delete(
      dbBookmarks,
    )..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 获取所有书签
  Future<List<DbBookmark>> getAllBookmarks() {
    return (select(
      dbBookmarks,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.createdTimestamp)])).get();
  }

  /// 插入书签
  Future<int> insertBookmark(DbBookmark bookmark) async {
    return into(dbBookmarks).insert(
      bookmark,
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 批量插入书签
  Future<void> insertBookmarkList(List<DbBookmark> list) async {
    await transaction(() async {
      for (final item in list) {
        await into(dbBookmarks).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // ==================== 排版缓存管理 ====================

  /// 保存排版缓存
  Future<void> saveLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
    required String pageOffsets, // JSON 格式
    required int totalPages,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await into(dbLayoutCaches).insert(
      DbLayoutCachesCompanion.insert(
        bookId: bookId,
        chapterId: chapterId,
        configHash: configHash,
        pageOffsets: pageOffsets,
        totalPages: totalPages,
        createdAt: now,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取排版缓存
  Future<DbLayoutCache?> getLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
  }) {
    return (select(dbLayoutCaches)..where(
          (tbl) =>
              tbl.bookId.equals(bookId) &
              tbl.chapterId.equals(chapterId) &
              tbl.configHash.equals(configHash),
        ))
        .getSingleOrNull();
  }

  /// 清除书籍的所有排版缓存
  Future<int> clearLayoutCache(int bookId) {
    return (delete(
      dbLayoutCaches,
    )..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 清除指定章节的排版缓存
  Future<int> clearChapterLayoutCache(int bookId, int chapterId) {
    return (delete(dbLayoutCaches)..where(
          (tbl) => tbl.bookId.equals(bookId) & tbl.chapterId.equals(chapterId),
        ))
        .go();
  }

  /// 获取书籍的所有排版缓存
  Future<List<DbLayoutCache>> getAllLayoutCache(int bookId) {
    return (select(
      dbLayoutCaches,
    )..where((tbl) => tbl.bookId.equals(bookId))).get();
  }

  // ==================== 阅读统计管理 ====================

  /// 获取阅读统计
  Future<DbReadingStats?> getReadingStats() async {
    return (select(
      dbReadingStatss,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
  }

  /// 初始化阅读统计
  Future<void> initReadingStats() async {
    await into(dbReadingStatss).insert(
      DbReadingStatssCompanion.insert(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// 更新阅读统计
  Future<void> updateReadingStats({
    required int totalReadingTimeSeconds,
    required int totalCharactersRead,
    required int booksReadCount,
    required int booksCompletedCount,
    required String? lastReadDate,
    required int consecutiveReadingDays,
  }) async {
    await (update(dbReadingStatss)..where((tbl) => tbl.id.equals(1))).write(
      DbReadingStatssCompanion(
        totalReadingTimeSeconds: Value(totalReadingTimeSeconds),
        totalCharactersRead: Value(totalCharactersRead),
        booksReadCount: Value(booksReadCount),
        booksCompletedCount: Value(booksCompletedCount),
        lastReadDate: Value(lastReadDate),
        consecutiveReadingDays: Value(consecutiveReadingDays),
      ),
    );
  }

  /// 记录阅读会话
  Future<void> recordReadingSession({
    required int bookId,
    required int chapterId,
    required int startTimestamp,
    required int endTimestamp,
    required int durationSeconds,
    required int charactersRead,
  }) async {
    await into(dbReadingSessions).insert(
      DbReadingSessionsCompanion.insert(
        bookId: bookId,
        chapterId: chapterId,
        startTimestamp: startTimestamp,
        endTimestamp: endTimestamp,
        durationSeconds: durationSeconds,
        charactersRead: Value(charactersRead),
      ),
    );
  }

  /// 更新每日阅读记录
  Future<void> updateDailyReadingRecord({
    required String date,
    required int readingTimeSeconds,
    required int charactersRead,
  }) async {
    await into(dbDailyReadingRecords).insert(
      DbDailyReadingRecordsCompanion.insert(
        date: date,
        readingTimeSeconds: Value(readingTimeSeconds),
        charactersRead: Value(charactersRead),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取指定日期的阅读记录
  Future<DbDailyReadingRecord?> getDailyReadingRecord(String date) {
    return (select(
      dbDailyReadingRecords,
    )..where((tbl) => tbl.date.equals(date))).getSingleOrNull();
  }

  /// 获取日期范围内的阅读记录
  Future<List<DbDailyReadingRecord>> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) {
    return (select(dbDailyReadingRecords)
          ..where(
            (tbl) =>
                tbl.date.isBiggerOrEqualValue(startDate) &
                tbl.date.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
        .get();
  }

  /// 获取最近 N 天的阅读记录
  Future<List<DbDailyReadingRecord>> getRecentReadingRecords(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final endDate = now;

    return getDailyReadingRecordsInRange(
      startDate: startDate.toString().split(' ')[0],
      endDate: endDate.toString().split(' ')[0],
    );
  }

  /// 获取今日阅读数据
  Future<(int, int)> getTodayReadingData() async {
    final today = DateTime.now().toString().split(' ')[0];
    final record = await getDailyReadingRecord(today);

    if (record == null) {
      return (0, 0);
    }

    return (record.readingTimeSeconds, record.charactersRead);
  }

  /// 获取连续阅读天数
  Future<int> getConsecutiveReadingDays() async {
    final stats = await getReadingStats();
    return stats?.consecutiveReadingDays ?? 0;
  }

  /// 更新书籍阅读计数
  Future<void> incrementBooksReadCount() async {
    final stats = await getReadingStats();
    if (stats == null) {
      await initReadingStats();
    }

    await (update(dbReadingStatss)..where((tbl) => tbl.id.equals(1))).write(
      DbReadingStatssCompanion(
        booksReadCount: Value((stats?.booksReadCount ?? 0) + 1),
      ),
    );
  }

  /// 更新完成阅读书籍计数
  Future<void> incrementBooksCompletedCount() async {
    final stats = await getReadingStats();
    if (stats == null) {
      await initReadingStats();
    }

    await (update(dbReadingStatss)..where((tbl) => tbl.id.equals(1))).write(
      DbReadingStatssCompanion(
        booksCompletedCount: Value((stats?.booksCompletedCount ?? 0) + 1),
      ),
    );
  }

  /// 计算平均阅读速度（字/分钟）
  Future<double> getReadingSpeed() async {
    final stats = await getReadingStats();
    if (stats == null || stats.totalReadingTimeSeconds == 0) {
      return 0.0;
    }

    return (stats.totalCharactersRead / stats.totalReadingTimeSeconds) * 60.0;
  }
}

/// 懒加载数据库连接
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'zephyr_reader.db'));
    return NativeDatabase.createInBackground(file);
  });
}

/// 数据库单例实例
AppDatabase? _databaseInstance;

/// 获取数据库单例（推荐方式）
///
/// 使用示例：
/// ```dart
/// final db = getDatabase();
/// ```
AppDatabase getDatabase() {
  _databaseInstance ??= AppDatabase(_openConnection());
  return _databaseInstance!;
}

/// 关闭数据库连接
///
/// 在应用退出时调用
Future<void> closeDatabase() async {
  await _databaseInstance?.close();
  _databaseInstance = null;
}
