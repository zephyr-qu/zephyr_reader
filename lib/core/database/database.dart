import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/books.dart';
import 'tables/bookmarks.dart';
import 'tables/chapters.dart';
import 'tables/reading_history.dart';
import 'tables/reading_progress.dart';
import 'tables/layout_cache.dart';
import 'tables/reading_stats.dart';
import 'tables/daily_reading_records.dart';
import 'tables/reading_sessions.dart';

part 'database.g.dart';

/// 应用数据库
@DriftDatabase(
  tables: [
    Books,
    Chapters,
    Bookmarks,
    ReadingHistories,
    ReadingProgresses,
    LayoutCaches,
    ReadingStatses,
    DailyReadingRecords,
    ReadingSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 从版本 1 升级到版本 2：添加新表并迁移书签数据
        if (from < 2) {
          // 1. 创建新表
          await m.create(readingProgresses);
          await m.create(layoutCaches);
          await m.create(readingStatses);
          await m.create(dailyReadingRecords);
          await m.create(readingSessions);

          // 2. 书签表结构变更 - 保留数据
          // 注意：由于表结构变化较大（字段名和类型都变了），无法直接迁移
          // 2.1 删除旧表（数据会丢失，建议用户在升级前备份）
          await m.drop(bookmarks);

          // 2.2 创建新表
          await m.create(bookmarks);

          // 注意：书签数据无法自动迁移，因为：
          // - 旧版使用自增 id，新版使用 UUID bookmarkId
          // - 旧版 createdAt 是 DateTime，新版 createdTimestamp 是 Unix 秒
          // - 旧版没有 title 字段，新版必须有
          // 用户需要重新添加书签
        }
        // 从版本 2 升级到版本 3：添加 position 字段到书签表
        if (from < 3) {
          await m.addColumn(bookmarks, bookmarks.position);
        }
      },
    );
  }

  /// 查询所有小说
  Future<List<Book>> getAllBooks() => select(books).get();

  /// 根据 ID 查询小说
  Future<Book?> getBookById(int id) =>
      (select(books)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// 搜索小说
  Future<List<Book>> searchBooks(String keyword) {
    return (select(books)..where(
          (tbl) => tbl.title.contains(keyword) | tbl.author.contains(keyword),
        ))
        .get();
  }

  /// 查询小说的所有章节
  Future<List<Chapter>> getChaptersByBookId(int bookId) {
    return (select(chapters)
          ..where((tbl) => tbl.bookId.equals(bookId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.chapterIndex)]))
        .get();
  }

  /// 根据小说 ID 和章节索引查询章节
  Future<Chapter?> getChapter(int bookId, int chapterIndex) {
    return (select(chapters)..where(
          (tbl) =>
              tbl.bookId.equals(bookId) & tbl.chapterIndex.equals(chapterIndex),
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
  Future<ReadingHistory?> getBookReadingHistory(int bookId) {
    return (select(
      readingHistories,
    )..where((tbl) => tbl.bookId.equals(bookId))).getSingleOrNull();
  }

  // ==================== 阅读进度管理 ====================

  /// 更新阅读进度
  Future<void> updateReadingProgress({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final progress = pageIndex / totalPages;

    await into(readingProgresses).insert(
      ReadingProgressesCompanion.insert(
        bookId: bookId,
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
  Future<ReadingProgressItem?> getReadingProgress(String bookId) {
    return (select(
      readingProgresses,
    )..where((tbl) => tbl.bookId.equals(bookId))).getSingleOrNull();
  }

  /// 清除阅读进度
  Future<void> clearReadingProgress(String bookId) {
    return (delete(
      readingProgresses,
    )..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 获取所有阅读进度
  Future<List<ReadingProgressItem>> getAllReadingProgress() {
    return (select(
      readingProgresses,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.lastReadTimestamp)])).get();
  }

  // ==================== 书签管理 ====================

  /// 添加书签
  Future<void> addBookmark({
    required String bookmarkId,
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required String title,
    required int position,
    required int createdTimestamp,
    String? note,
  }) async {
    await into(bookmarks).insert(
      BookmarksCompanion.insert(
        bookmarkId: bookmarkId,
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        title: title,
        createdTimestamp: createdTimestamp,
        note: Value(note),
        position: position,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarks(int bookId) {
    return (select(bookmarks)..where((tbl) => tbl.bookId.equals(bookId))).get();
  }

  /// 删除书签
  Future<void> removeBookmark(String bookmarkId) {
    return (delete(
      bookmarks,
    )..where((tbl) => tbl.bookmarkId.equals(bookmarkId))).go();
  }

  /// 清除书籍的所有书签
  Future<void> clearBookmarks(int bookId) {
    return (delete(bookmarks)..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() {
    return (select(
      bookmarks,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.createdTimestamp)])).get();
  }

  // ==================== 排版缓存管理 ====================

  /// 保存排版缓存
  Future<void> saveLayoutCache({
    required String bookId,
    required int chapterId,
    required String configHash,
    required String pageOffsets, // JSON 格式
    required int totalPages,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await into(layoutCaches).insert(
      LayoutCachesCompanion.insert(
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
  Future<LayoutCacheItem?> getLayoutCache({
    required String bookId,
    required int chapterId,
    required String configHash,
  }) {
    return (select(layoutCaches)..where(
          (tbl) =>
              tbl.bookId.equals(bookId) &
              tbl.chapterId.equals(chapterId) &
              tbl.configHash.equals(configHash),
        ))
        .getSingleOrNull();
  }

  /// 清除书籍的所有排版缓存
  Future<int> clearLayoutCache(String bookId) {
    return (delete(
      layoutCaches,
    )..where((tbl) => tbl.bookId.equals(bookId))).go();
  }

  /// 清除指定章节的排版缓存
  Future<int> clearChapterLayoutCache(String bookId, int chapterId) {
    return (delete(layoutCaches)..where(
          (tbl) => tbl.bookId.equals(bookId) & tbl.chapterId.equals(chapterId),
        ))
        .go();
  }

  /// 获取书籍的所有排版缓存
  Future<List<LayoutCacheItem>> getAllLayoutCache(String bookId) {
    return (select(
      layoutCaches,
    )..where((tbl) => tbl.bookId.equals(bookId))).get();
  }

  // ==================== 阅读统计管理 ====================

  /// 获取阅读统计
  Future<ReadingStatsItem?> getReadingStats() async {
    return (select(
      readingStatses,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
  }

  /// 初始化阅读统计
  Future<void> initReadingStats() async {
    await into(readingStatses).insert(
      ReadingStatsesCompanion.insert(id: Value(1)),
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
    await (update(readingStatses)..where((tbl) => tbl.id.equals(1))).write(
      ReadingStatsesCompanion(
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
    required String sessionId,
    required String bookId,
    required int chapterId,
    required int startTimestamp,
    required int endTimestamp,
    required int durationSeconds,
    required int charactersRead,
  }) async {
    await into(readingSessions).insert(
      ReadingSessionsCompanion.insert(
        sessionId: sessionId,
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
    await into(dailyReadingRecords).insert(
      DailyReadingRecordsCompanion.insert(
        date: date,
        readingTimeSeconds: Value(readingTimeSeconds),
        charactersRead: Value(charactersRead),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// 获取指定日期的阅读记录
  Future<DailyReadingRecordItem?> getDailyReadingRecord(String date) {
    return (select(
      dailyReadingRecords,
    )..where((tbl) => tbl.date.equals(date))).getSingleOrNull();
  }

  /// 获取日期范围内的阅读记录
  Future<List<DailyReadingRecordItem>> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) {
    return (select(dailyReadingRecords)
          ..where(
            (tbl) =>
                tbl.date.isBiggerOrEqualValue(startDate) &
                tbl.date.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.date)]))
        .get();
  }

  /// 获取最近 N 天的阅读记录
  Future<List<DailyReadingRecordItem>> getRecentReadingRecords(int days) async {
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

    await (update(readingStatses)..where((tbl) => tbl.id.equals(1))).write(
      ReadingStatsesCompanion(
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

    await (update(readingStatses)..where((tbl) => tbl.id.equals(1))).write(
      ReadingStatsesCompanion(
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
