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

  List<DbBookRecord> getAllBooks() {
    final result = rust_storage.getAllBooks();
    return _unwrap<List<DbBookRecord>>(result);
  }

  void saveBook(DbBookRecord book) {
    final result = rust_storage.saveBook(book: book);
    _unwrap<void>(result);
  }

  void deleteBook(String bookId) {
    final result =  rust_storage.deleteBook(bookId: bookId);
    _unwrap<void>(result);
  }

  List<DbBookRecord> searchBooks(String keyword) {
    final result =  rust_storage.searchBooks(keyword: keyword);
    return _unwrap<List<DbBookRecord>>(result);
  }

  // ==================== Chapters ====================

  List<DbChapter> getChaptersByBook(String bookId) {
    final result =  rust_storage.getChaptersByBook(bookId: bookId);
    return _unwrap<List<DbChapter>>(result);
  }

  void saveChapters(String bookId, List<DbChapter> chapters) {
    final result =  rust_storage.saveChapters(
      bookId: bookId,
      chapters: chapters,
    );
    _unwrap<void>(result);
  }

  void deleteChaptersByBook(String bookId) {
    final result =  rust_storage.deleteChaptersByBook(bookId: bookId);
    _unwrap<void>(result);
  }

  // ==================== Bookmarks ====================

  List<DbBookmark> getBookmarks(String bookId) {
    final result =  rust_storage.getBookmarks(bookId: bookId);
    return _unwrap<List<DbBookmark>>(result);
  }

  DbBookmark? getBookmarkById(String bookmarkId) {
    final result =  rust_storage.getBookmark(bookmarkId: bookmarkId);
    return _unwrapNullable<DbBookmark>(result);
  }

  Future<DbBookmark> createBookmark(DbBookmark bookmark) async {
    final result =  rust_storage.createBookmark(bookmark: bookmark);
    return _unwrap<DbBookmark>(result);
  }

  void deleteBookmark(String bookmarkId) {
    final result =  rust_storage.deleteBookmark(bookmarkId: bookmarkId);
    _unwrap<void>(result);
  }

  // ==================== Reading Progress ====================

  DbReadingProgress? getReadingProgress(String bookId) {
    final result =  rust_storage.getReadingProgress(bookId: bookId);
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
     rust_storage.saveReadingProgress(
      progress: DbReadingProgress(bookId: bookId, chapterIndex: chapterIndex, charOffset: charOffset, pageIndex: pageIndex, totalPages: totalPages, progress: 0, readingTimeSeconds: readingTimeSeconds, lastReadAt: DateTime.now(), isCompleted: false)
    );
  }

  void clearReadingProgress(String bookId) {
     rust_storage.clearReadingProgress(bookId: bookId);
  }

  // ==================== Stats ====================

  DbGlobalStats getReadingStats() {
    final globalStats = getGlobalReadingStats();
    final todayStats =  getTodayReadingStats();
    return DbGlobalStats(
      totalReadingTimeSeconds: globalStats.totalReadingTimeSeconds.toInt(),
      totalCharactersRead: globalStats.totalCharactersRead.toInt(),
      booksReadCount: globalStats.booksReadCount,
      booksCompletedCount: globalStats.booksCompletedCount,
      consecutiveReadingDays: globalStats.consecutiveReadingDays,
      todayReadingTimeSeconds: todayStats.todayReadingTimeSeconds,
      todayCharactersRead: todayStats.totalCharactersRead,
      averageReadingSpeed: globalStats.averageReadingSpeed,
      totalBooksCount: globalStats.totalBooksCount,
      totalNotesCount: globalStats.totalNotesCount,
      totalBookmarksCount: globalStats.totalBookmarksCount,
      maxConsecutiveReadingDays: globalStats.maxConsecutiveReadingDays,
    );
  }

  (int, int) getTodayReadingData() {
    final todayStats =  getTodayReadingStats();
    return (todayStats.todayReadingTimeSeconds, todayStats.totalCharactersRead);
  }

  DbDailyReadingStats getDailyReadingRecord(String date) {
     getDailyReadingRecordsInRange(startDate: date, endDate: date);
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
    final result =  rust_storage.getReadingStatsRange(
      startDate: startDate,
      endDate: endDate,
    );
    return _unwrapNullable<DbDailyReadingStats>(result);
  }

  DbDailyReadingStats? getRecentReadingRecords(int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days - 1));
    final endDate = now.toString().split(' ')[0];
    final stats =  getDailyReadingRecordsInRange(
      startDate: startDate.toString().split(' ')[0],
      endDate: endDate,
    );
    return _unwrapNullable<DbDailyReadingStats>(stats);
  }

  int getConsecutiveReadingDays() {
    final globalStats = getGlobalReadingStats();
    return globalStats.consecutiveReadingDays;
  }

  double getReadingSpeed() {
    final globalStats = getGlobalReadingStats();
    return globalStats.averageReadingSpeed;
  }

  DbGlobalStats getGlobalReadingStats() {
    final result =  rust_storage.getGlobalReadingStats();
    return _unwrap<DbGlobalStats>(result);
  }

  DbGlobalStats getTodayReadingStats() {
    final result =  rust_storage.getTodayReadingStats();
    return _unwrap<DbGlobalStats>(result);
  }

  Future<List<DbDailyReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async {
    final result =  rust_storage.getReadingStatsRange(
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
     rust_storage.recordReadingSession(
      session: DbReadingSession(bookId: bookId, chapterIndex: chapterIndex, startCharOffset: startOffset, endCharOffset: endOffset, startedAt: DateTime.now(), endedAt: DateTime.now(), durationSeconds: durationSeconds, charactersRead: charactersRead, id: ' ')

    );
  }

  List<DbReadingSession> getReadingSessions(String bookId, {int limit = 100}) {
    final result = rust_storage.getReadingSessions(
      bookId: bookId,
      limit: BigInt.from(limit),
    );
    return _unwrap<List<DbReadingSession>>(result);
  }

  // ==================== Categories ====================

  List<DbBookCategory> getAllCategories() {
    final result =  rust_storage.getAllCategories();
    return _unwrap<List<DbBookCategory>>(result);
  }

  void saveCategory(DbBookCategory category) {
    final result =  rust_storage.saveCategory(category: category);
    _unwrap<void>(result);
  }

  void deleteCategory(String categoryId) {
    final result =  rust_storage.deleteCategory(categoryId: categoryId);
    _unwrap<void>(result);
  }

  List<DbBookCategory> getCategoriesForBook(String bookId) {
    final result =  rust_storage.getCategoriesForBook(bookId: bookId);
    return _unwrap<List<DbBookCategory>>(result);
  }

  Future<void> setCategoriesForBook(
    String bookId,
    List<String> categoryIds,
  ) async {
    final result =  rust_storage.setCategoriesForBook(
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
     rust_storage.saveLayoutCache(
       cache: DbLayoutCache(
        totalPages: totalPages,
        pageOffsets: pageOffsets,
        createdAt: DateTime.now(),
       ),
       key: LayoutCacheKey(bookId: bookId, chapterIndex: chapterIndex, configHash: configHash),
    );
  }

  Future<DbLayoutCache?> getLayoutCache({
    required String bookId,
    required int chapterIndex,
    required String configHash,
  }) async {
    final result =  rust_storage.getLayoutCache(
      bookId: bookId,
      chapterIndex: chapterIndex,
      configHash: configHash,
    );
    return _unwrapNullable<DbLayoutCache>(result);
  }

  void clearLayoutCache(String bookId) {
     rust_storage.clearLayoutCache(bookId: bookId);
  }

  // ==================== Notes ====================

  DbNote createNote(DbNote note) {
    final result = rust_storage.createNote(note: note);
    return _unwrap<DbNote>(result);
  }

  List<DbNote> getNotes(String bookId, {DbNoteType? noteType}) {
    final result = rust_storage.getNotes(bookId: bookId, noteType: noteType);
    return _unwrap<List<DbNote>>(result);
  }

  void deleteNote(String noteId) {
    rust_storage.deleteNote(noteId: noteId);
  }

  Map<String, int> getNoteStats(String bookId) {
    final result = rust_storage.getNoteStats(bookId: bookId);
    final value = (result as dynamic).value;
    if (value == null) return {'total': 0, 'highlights': 0, 'annotations': 0};
    return {
      'total': (value.totalCount ?? value.total_count ?? 0) as int,
      'highlights': (value.highlightCount ?? value.highlight_count ?? 0) as int,
      'annotations': (value.annotationCount ?? value.annotation_count ?? 0) as int,
    };
  }

  void putGlobalReadingStats(DbGlobalStats stats) {
    rust_storage.putGlobalReadingStats(stats: stats);
  }
}