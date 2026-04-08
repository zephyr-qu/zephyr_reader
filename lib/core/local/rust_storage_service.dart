/// Rust 存储服务
///
/// 封装 Rust FFI 存储调用，为 Flutter 侧提供统一接口
library;

import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_storage;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 解包 Rust ApiResult
T _unwrap<T>(dynamic result) {
  final value = (result as dynamic).value;
  if (value == null) throw Exception('Rust API returned null');
  return value as T;
}

T? _unwrapNullable<T>(dynamic result) {
  return (result as dynamic).value as T?;
}

class RustStorageService {
  static final RustStorageService _instance = RustStorageService._internal();
  factory RustStorageService() => _instance;
  RustStorageService._internal();

  // ==================== Books ====================

  Future<List<DbBookRecord>> getAllBooks() async {
    final result = await rust_storage.getAllBooks();
    return _unwrap<List<DbBookRecord>>(result);
  }

  Future<void> saveBook(DbBookRecord book) async {
    final result = await rust_storage.saveBook(book: book);
    _unwrap<void>(result);
  }

  Future<void> deleteBook(String bookId) async {
    final result = await rust_storage.deleteBook(bookId: bookId);
    _unwrap<void>(result);
  }

  Future<List<DbBookRecord>> searchBooks(String keyword) async {
    final result = await rust_storage.searchBooks(keyword: keyword);
    return _unwrap<List<DbBookRecord>>(result);
  }

  // ==================== Chapters ====================

  Future<List<DbChapter>> getChaptersByBook(String bookId) async {
    final result = await rust_storage.getChaptersByBook(bookId: bookId);
    return _unwrap<List<DbChapter>>(result);
  }

  Future<void> saveChapters(String bookId, List<DbChapter> chapters) async {
    final result = await rust_storage.saveChapters(
      bookId: bookId,
      chapters: chapters,
    );
    _unwrap<void>(result);
  }

  Future<void> deleteChaptersByBook(String bookId) async {
    final result = await rust_storage.deleteChaptersByBook(bookId: bookId);
    _unwrap<void>(result);
  }

  // ==================== Bookmarks ====================

  Future<List<DbBookmark>> getBookmarks(String bookId) async {
    final result = await rust_storage.getBookmarks(bookId: bookId);
    return _unwrap<List<DbBookmark>>(result);
  }

  Future<DbBookmark> createBookmark({
    required String bookId,
    required int chapterIndex,
    required int charOffset,
    String? title,
  }) async {
    final result = await rust_storage.createBookmark(
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      title: title,
    );
    return _unwrap<DbBookmark>(result);
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    final result = await rust_storage.deleteBookmark(bookmarkId: bookmarkId);
    _unwrap<void>(result);
  }

  // ==================== Reading Progress ====================

  Future<DbReadingProgress?> getReadingProgress(String bookId) async {
    final result = await rust_storage.getReadingProgress(bookId: bookId);
    return _unwrapNullable<DbReadingProgress>(result);
  }

  Future<void> saveReadingProgress({
    required String bookId,
    required int chapterIndex,
    required int charOffset,
    required int pageIndex,
    required int totalPages,
    required int readingTimeSeconds,
  }) async {
    await rust_storage.saveReadingProgress(
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      pageIndex: pageIndex,
      totalPages: totalPages,
      readingTimeSeconds: readingTimeSeconds,
    );
  }

  Future<void> clearReadingProgress(String bookId) async {
    await rust_storage.clearReadingProgress(bookId: bookId);
  }

  // ==================== Stats ====================

  Future<DbGlobalStats> getReadingStats() async {
    final globalStats = await getGlobalReadingStats();
    final todayStats = await getTodayReadingStats();
    return DbGlobalStats(
      totalReadingTimeSeconds: globalStats.totalReadingTimeSeconds.toInt(),
      totalCharactersRead: globalStats.totalCharactersRead.toInt(),
      booksReadCount: globalStats.booksReadCount,
      booksCompletedCount: globalStats.booksCompletedCount,
      consecutiveReadingDays: globalStats.consecutiveReadingDays,
      todayReadingTimeSeconds: todayStats.todayReadingTimeSeconds,
      todayCharactersRead: todayStats.totalCharactersRead,
      averageReadingSpeed: globalStats.averageReadingSpeed,
    );
  }

  Future<(int, int)> getTodayReadingData() async {
    final todayStats = await getTodayReadingStats();
    return (todayStats.todayReadingTimeSeconds, todayStats.totalCharactersRead);
  }

  Future<DbDailyReadingStats> getDailyReadingRecord(String date) async {
    await getDailyReadingRecordsInRange(startDate: date, endDate: date);
    return DbDailyReadingStats(
      date: date,
      chaptersRead: 0,
      pagesRead: 0,
      totalReadingTimeSeconds: 0,
      totalCharactersRead: 0,
      booksRead: [],
      sessionCount: 0,
    );
  }

  Future<DbDailyReadingStats?> getDailyReadingRecordsInRange({
    required String startDate,
    required String endDate,
  }) async {
    final result = await rust_storage.getReadingStatsRange(
      startDate: startDate,
      endDate: endDate,
    );
    return _unwrapNullable<DbDailyReadingStats>(result);
  }

  Future<DbDailyReadingStats?> getRecentReadingRecords(int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final endDate = now.toString().split(' ')[0];
    final stats = await getDailyReadingRecordsInRange(
      startDate: startDate.toString().split(' ')[0],
      endDate: endDate,
    );
    return _unwrapNullable<DbDailyReadingStats>(stats);
  }

  Future<int> getConsecutiveReadingDays() async {
    final globalStats = await getGlobalReadingStats();
    return globalStats.consecutiveReadingDays;
  }

  Future<double> getReadingSpeed() async {
    final globalStats = await getGlobalReadingStats();
    return globalStats.averageReadingSpeed;
  }

  Future<DbGlobalStats> getGlobalReadingStats() async {
    final result = await rust_storage.getGlobalReadingStats();
    return _unwrap<DbGlobalStats>(result);
  }

  Future<DbGlobalStats> getTodayReadingStats() async {
    final result = await rust_storage.getTodayReadingStats();
    return _unwrap<DbGlobalStats>(result);
  }

  Future<List<DbDailyReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async {
    final result = await rust_storage.getReadingStatsRange(
      startDate: startDate,
      endDate: endDate,
    );
    return _unwrap<List<DbDailyReadingStats>>(result);
  }

  Future<void> recordReadingSession({
    required String bookId,
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required int durationSeconds,
    required int charactersRead,
  }) async {
    await rust_storage.recordReadingSession(
      bookId: bookId,
      chapterIndex: chapterIndex,
      startOffset: startOffset,
      endOffset: endOffset,
      durationSeconds: durationSeconds,
      charactersRead: charactersRead,
    );
  }

  // ==================== Categories ====================

  Future<List<DbBookCategory>> getAllCategories() async {
    final result = await rust_storage.getAllCategories();
    return _unwrap<List<DbBookCategory>>(result);
  }

  Future<void> saveCategory(DbBookCategory category) async {
    final result = await rust_storage.saveCategory(category: category);
    _unwrap<void>(result);
  }

  Future<void> deleteCategory(String categoryId) async {
    final result = await rust_storage.deleteCategory(categoryId: categoryId);
    _unwrap<void>(result);
  }

  Future<List<DbBookCategory>> getCategoriesForBook(String bookId) async {
    final result = await rust_storage.getCategoriesForBook(bookId: bookId);
    return _unwrap<List<DbBookCategory>>(result);
  }

  Future<void> setCategoriesForBook(
    String bookId,
    List<String> categoryIds,
  ) async {
    final result = await rust_storage.setCategoriesForBook(
      bookId: bookId,
      categoryIds: categoryIds,
    );
    _unwrap<void>(result);
  }

  // ==================== Layout Cache ====================

  Future<void> saveLayoutCache({
    required String bookId,
    required int chapterIndex,
    required String configHash,
    required List<(int, int)> pageOffsets,
    required int totalPages,
  }) async {
    await rust_storage.saveLayoutCache(
      bookId: bookId,
      chapterIndex: chapterIndex,
      configHash: configHash,
      pageOffsets: pageOffsets,
      totalPages: totalPages,
    );
  }

  Future<DbLayoutCache?> getLayoutCache({
    required String bookId,
    required int chapterIndex,
    required String configHash,
  }) async {
    final result = await rust_storage.getLayoutCache(
      bookId: bookId,
      chapterIndex: chapterIndex,
      configHash: configHash,
    );
    return _unwrapNullable<DbLayoutCache>(result);
  }

  Future<void> clearLayoutCache(String bookId) async {
    await rust_storage.clearLayoutCache(bookId: bookId);
  }
}
