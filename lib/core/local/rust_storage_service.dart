/// Rust 存储服务
///
/// 封装 Rust FFI 存储调用，为 Flutter 侧提供统一接口
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_storage;
import 'package:zephyr_reader/src/rust/domain/error.dart' as rust_error;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/error/app_error.dart';

@Singleton()
class RustStorageService {
  RustStorageService();

  /// 将 Rust [AppError] 转换为 Flutter [AppError]
  AppError _fromRustError(rust_error.AppError e) {
    return e.when(
      fileNotFound: (path) => AppError(
        type: ErrorType.file,
        message: 'File not found: $path',
        originalError: e,
        extraData: {'path': path},
      ),
      fileReadError: (path, details) => AppError(
        type: ErrorType.file,
        message: details,
        originalError: e,
        extraData: {'path': path},
      ),
      unsupportedFormat: (format) => AppError(
        type: ErrorType.parse,
        message: 'Unsupported format: $format',
        originalError: e,
      ),
      epubParseError: (reason) => AppError(
        type: ErrorType.parse,
        message: reason,
        originalError: e,
      ),
      pdfParseError: (reason) => AppError(
        type: ErrorType.parse,
        message: reason,
        originalError: e,
      ),
      chapterExtractError: (index, reason) => AppError(
        type: ErrorType.parse,
        message: reason,
        originalError: e,
        extraData: {'chapterIndex': index},
      ),
      typesetConfigError: (reason) => AppError(
        type: ErrorType.parse,
        message: reason,
        originalError: e,
      ),
      databaseError: (reason) => AppError(
        type: ErrorType.database,
        message: reason,
        originalError: e,
      ),
      searchError: (reason) => AppError(
        type: ErrorType.database,
        message: reason,
        originalError: e,
      ),
      securityError: (reason, path) => AppError(
        type: ErrorType.permission,
        message: reason,
        originalError: e,
        extraData: {'path': path},
      ),
      invalidInput: (reason) => AppError(
        type: ErrorType.validation,
        message: reason,
        originalError: e,
      ),
      internalError: (reason) => AppError(
        type: ErrorType.unknown,
        message: reason,
        originalError: e,
      ),
      other: (message) => AppError(
        type: ErrorType.unknown,
        message: message,
        originalError: e,
      ),
    );
  }

  /// 统一异常转换包装
  ///
  /// 捕获 Rust [AppError] 并转为 Flutter [AppError]，其他异常直接透传。
  Future<T> _call<T>(Future<T> Function() block) async {
    try {
      return await block();
    } on rust_error.AppError catch (e) {
      throw _fromRustError(e);
    }
  }

  // ==================== Books ====================

  Future<List<Book>> getAllBooks() => _call(() async =>
      await rust_storage.getAllBooks());

  Future<void> saveBook(Book book) => _call(() async =>
      await rust_storage.saveBook(book: book));

  Future<void> deleteBook(String bookId) => _call(() async =>
      await rust_storage.deleteBook(bookId: bookId));

  Future<List<Book>> searchBooks(String keyword) => _call(() async =>
      await rust_storage.searchBooks(keyword: keyword));

  Future<Book?> getBook(String bookId) => _call(() async =>
      await rust_storage.getBook(bookId: bookId));

  Future<List<Book>> getBooksByStatus(BookStatus status) => _call(() async =>
      await rust_storage.getBooksByStatus(status: status)
          );

  Future<List<Book>> getPinnedBooks() => _call(() async =>
      await rust_storage.getPinnedBooks());

  Future<List<Book>> getRecentlyReadBooks(int limit) => _call(() async =>
      await rust_storage.getRecentlyReadBooks(limit: BigInt.from(limit))
          );

  Future<List<Book>> getBooksPaginated({
    required int limit,
    required int offset,
    String? sortBy,
    String? sortOrder,
  }) =>
      _call(() async =>
          await rust_storage.getBooksPaginated(
            limit: limit,
            offset: offset,
            sortBy: sortBy,
            sortOrder: sortOrder,
          ));

  Future<int> getBookCount() => _call(() async =>
      (await rust_storage.getBookCount()).toInt());

  Future<void> updateBookStatus(String bookId, BookStatus status) =>
      _call(() async =>
          await rust_storage.updateBookStatus(
                  bookId: bookId, status: status)
              );

  Future<void> updateBookPin(String bookId, bool isPinned) =>
      _call(() async =>
          await rust_storage.updateBookPin(
                  bookId: bookId, isPinned: isPinned)
              );

  // ==================== Chapters ====================

  Future<List<Chapter>> getChaptersByBook(String bookId) => _call(() async =>
      await rust_storage.getChaptersByBook(bookId: bookId)
          );

  Future<void> saveChapters(
      String bookId, List<Chapter> chapters) =>
      _call(() async =>
          await rust_storage.saveChapters(
                  bookId: bookId, chapters: chapters)
              );

  Future<void> deleteChaptersByBook(String bookId) => _call(() async =>
      await rust_storage.deleteChaptersByBook(bookId: bookId)
          );

  Future<Chapter?> getChapterByIndex(
      String bookId, int chapterIndex) =>
      _call(() async =>
          await rust_storage.getChapterByIndex(
                  bookId: bookId, chapterIndex: chapterIndex)
              );

  // ==================== Bookmarks ====================

  Future<List<Bookmark>> getBookmarks(String bookId) => _call(() async =>
      await rust_storage.getBookmarks(bookId: bookId)
          );

  Future<Bookmark?> getBookmark(String bookmarkId) => _call(() async =>
      await rust_storage.getBookmark(bookmarkId: bookmarkId)
          );

  Future<void> createBookmark(Bookmark bookmark) => _call(() async =>
      await rust_storage.createBookmark(bookmark: bookmark)
          );

  Future<void> deleteBookmark(String bookmarkId) => _call(() async =>
      await rust_storage.deleteBookmark(bookmarkId: bookmarkId)
          );

  Future<void> deleteBookmarksByBook(String bookId) => _call(() async =>
      await rust_storage.deleteBookmarksByBook(bookId: bookId)
          );

  Future<void> importBookmarks(List<Bookmark> bookmarks) => _call(() async =>
      await rust_storage.importBookmarks(bookmarks: bookmarks)
          );

  Future<List<Bookmark>> syncBookmarks(
    List<Bookmark> localBookmarks,
    List<Bookmark> remoteBookmarks,
  ) =>
      _call(() async =>
          await rust_storage.syncBookmarks(
            localBookmarks: localBookmarks,
            remoteBookmarks: remoteBookmarks,
          ));

  Future<int> getBookmarkStats(String bookId) => _call(() async =>
      await rust_storage.getBookmarkStats(bookId: bookId)
          );

  // ==================== Reading Progress ====================

  Future<ReadingProgress?> getReadingProgress(String bookId) =>
      _call(() async =>
          await rust_storage.getReadingProgress(bookId: bookId)
              );

  Future<void> saveReadingProgress(ReadingProgress progress) =>
      _call(() async =>
          await rust_storage.saveReadingProgress(progress: progress)
              );

  Future<void> clearReadingProgress(String bookId) => _call(() async =>
      await rust_storage.clearReadingProgress(bookId: bookId)
          );

  // ==================== Reading Sessions ====================

  Future<void> recordReadingSession(ReadingSession session) =>
      _call(() async =>
          await rust_storage.recordReadingSession(session: session)
              );

  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) =>
      _call(() async =>
          await rust_storage.getReadingSessions(
                  bookId: bookId, limit: BigInt.from(limit))
              );

  Future<List<ReadingSession>> getRecentSessions(int limit) =>
      _call(() async =>
          await rust_storage.getRecentSessions(limit: BigInt.from(limit))
              );

  Future<void> deleteSessionsByBook(String bookId) => _call(() async =>
      await rust_storage.deleteSessionsByBook(bookId: bookId)
          );

  // ==================== Stats ====================

  Future<GlobalStats> getGlobalReadingStats() => _call(() async =>
      rust_storage.getGlobalReadingStats());

  Future<List<ReadingStats>> getTodayReadingStats() => _call(() async =>
      await rust_storage.getTodayReadingStats()
          );

  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) =>
      _call(() async =>
          await rust_storage.getReadingStatsRange(
                  startDate: startDate, endDate: endDate)
              );

  Future<void> updateDailyStats(ReadingStats stats) => _call(() async =>
      await rust_storage.updateDailyStats(stats: stats));

  // ==================== Categories ====================

  Future<List<BookCategory>> getAllCategories() => _call(() async =>
      await rust_storage.getAllCategories());

  Future<void> saveCategory(BookCategory category) => _call(() async =>
      await rust_storage.saveCategory(category: category));

  Future<void> deleteCategory(String categoryId) => _call(() async =>
      await rust_storage.deleteCategory(categoryId: categoryId)
          );

  Future<BookCategory?> getCategory(String categoryId) => _call(() async =>
      await rust_storage.getCategory(categoryId: categoryId)
          );

  Future<List<BookCategory>> getCategoriesForBook(String bookId) =>
      _call(() async =>
          await rust_storage.getCategoriesForBook(bookId: bookId)
              );

  Future<void> assignCategoryToBook(
          String bookId, String categoryId) =>
      _call(() async =>
          await rust_storage.assignCategoryToBook(
                  bookId: bookId, categoryId: categoryId)
              );

  Future<void> removeCategoryFromBook(
          String bookId, String categoryId) =>
      _call(() async =>
          await rust_storage.removeCategoryFromBook(
                  bookId: bookId, categoryId: categoryId)
              );

  Future<void> setCategoriesForBook(
    String bookId,
    List<String> categoryIds,
  ) =>
      _call(() async =>
          await rust_storage.setCategoriesForBook(
                  bookId: bookId, categoryIds: categoryIds)
              );

  Future<void> clearCategoriesForBook(String bookId) => _call(() async =>
      await rust_storage.clearCategoriesForBook(bookId: bookId)
          );

  // ==================== Layout Cache ====================

  Future<void> saveLayoutCache({
    required LayoutCache cache,
    required LayoutCacheKey key,
  }) =>
      _call(() async =>
          await rust_storage.saveLayoutCache(cache: cache, key: key)
              );

  Future<LayoutCache?> getLayoutCache({
    required String bookId,
    required int chapterIndex,
    required String configHash,
  }) =>
      _call(() async =>
          await rust_storage.getLayoutCache(
                  bookId: bookId,
                  chapterIndex: chapterIndex,
                  configHash: configHash)
              );

  Future<void> clearLayoutCache(String bookId) => _call(() async =>
      await rust_storage.clearLayoutCache(bookId: bookId));

  Future<BigInt> cleanupExpiredLayoutCache(int maxAgeDays) => _call(() async =>
      await rust_storage.cleanupExpiredLayoutCache(maxAgeDays: maxAgeDays)
          );

  // ==================== Notes ====================

  Future<Note> createNote(Note note) => _call(() async =>
      await rust_storage.createNote(note: note));

  Future<void> updateNote(Note note) => _call(() async =>
      await rust_storage.updateNote(note: note));

  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) =>
      _call(() async =>
          await rust_storage.getNotes(bookId: bookId, noteType: noteType)
              );

  Future<void> deleteNote(String noteId) => _call(() async =>
      await rust_storage.deleteNote(noteId: noteId));

  Future<void> deleteNotesByBook(String bookId) => _call(() async =>
      await rust_storage.deleteNotesByBook(bookId: bookId));

  Future<NoteStats> getNoteStats(String bookId) => _call(() async =>
      rust_storage.getNoteStats(bookId: bookId));

  // ==================== Database ====================

  Future<void> exportDatabase(String destPath) => _call(() async =>
      await rust_storage.exportDatabase(destPath: destPath));

  Future<void> restoreDatabase(String backupPath) => _call(() async =>
      await rust_storage.restoreDatabase(backupPath: backupPath)
          );
}
