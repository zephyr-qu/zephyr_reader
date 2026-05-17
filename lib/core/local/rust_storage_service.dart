/// Rust 存储服务
///
/// 封装 Rust FFI 存储调用，为 Flutter 侧提供统一接口
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_storage;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Singleton()
class RustStorageService {
  RustStorageService();

  // ==================== Books ====================

  Future<List<Book>> getAllBooks() async => await rust_storage.getAllBooks();

  Future<void> saveBook(Book book) async => await rust_storage.saveBook(book: book);

  Future<void> deleteBook(String bookId) async => await rust_storage.deleteBook(bookId: bookId);

  Future<List<Book>> searchBooks(String keyword) async => await rust_storage.searchBooks(keyword: keyword);

  Future<Book?> getBook(String bookId) async => await rust_storage.getBook(bookId: bookId);

  Future<List<Book>> getBooksByStatus(BookStatus status) async =>
      await rust_storage.getBooksByStatus(status: status);

  Future<List<Book>> getPinnedBooks() async => await rust_storage.getPinnedBooks();

  Future<List<Book>> getRecentlyReadBooks(int limit) async =>
      await rust_storage.getRecentlyReadBooks(limit: BigInt.from(limit));

  Future<List<Book>> getBooksPaginated({
    required int limit,
    required int offset,
    String? sortBy,
    String? sortOrder,
  }) async =>
      await rust_storage.getBooksPaginated(
        limit: limit,
        offset: offset,
        sortBy: sortBy,
        sortOrder: sortOrder,
      );

  Future<int> getBookCount() async =>
      (await rust_storage.getBookCount()).toInt();

  Future<void> updateBookStatus(String bookId, BookStatus status) async =>
      await rust_storage.updateBookStatus(bookId: bookId, status: status);

  Future<void> updateBookPin(String bookId, bool isPinned) async =>
      await rust_storage.updateBookPin(bookId: bookId, isPinned: isPinned);

  // ==================== Chapters ====================

  Future<List<Chapter>> getChaptersByBook(String bookId) async =>
      await rust_storage.getChaptersByBook(bookId: bookId);

  Future<void> saveChapters(String bookId, List<Chapter> chapters) async =>
      await rust_storage.saveChapters(bookId: bookId, chapters: chapters);

  Future<void> deleteChaptersByBook(String bookId) async =>
      await rust_storage.deleteChaptersByBook(bookId: bookId);

  Future<Chapter?> getChapterByIndex(String bookId, int chapterIndex) async =>
      await rust_storage.getChapterByIndex(bookId: bookId, chapterIndex: chapterIndex);

  // ==================== Bookmarks ====================

  Future<List<Bookmark>> getBookmarks(String bookId) async =>
      await rust_storage.getBookmarks(bookId: bookId);

  Future<Bookmark?> getBookmark(String bookmarkId) async =>
      await rust_storage.getBookmark(bookmarkId: bookmarkId);

  Future<void> createBookmark(Bookmark bookmark) async =>
      await rust_storage.createBookmark(bookmark: bookmark);

  Future<void> deleteBookmark(String bookmarkId) async =>
      await rust_storage.deleteBookmark(bookmarkId: bookmarkId);

  Future<void> deleteBookmarksByBook(String bookId) async =>
      await rust_storage.deleteBookmarksByBook(bookId: bookId);

  Future<void> importBookmarks(List<Bookmark> bookmarks) async =>
      await rust_storage.importBookmarks(bookmarks: bookmarks);

  Future<List<Bookmark>> syncBookmarks(
    List<Bookmark> localBookmarks,
    List<Bookmark> remoteBookmarks,
  ) async =>
      await rust_storage.syncBookmarks(
        localBookmarks: localBookmarks,
        remoteBookmarks: remoteBookmarks,
      );

  Future<int> getBookmarkStats(String bookId) async =>
      await rust_storage.getBookmarkStats(bookId: bookId);

  // ==================== Reading Progress ====================

  Future<ReadingProgress?> getReadingProgress(String bookId) async =>
      await rust_storage.getReadingProgress(bookId: bookId);

  Future<void> saveReadingProgress(ReadingProgress progress) async =>
      await rust_storage.saveReadingProgress(progress: progress);

  Future<void> clearReadingProgress(String bookId) async =>
      await rust_storage.clearReadingProgress(bookId: bookId);

  // ==================== Reading Sessions ====================

  Future<void> recordReadingSession(ReadingSession session) async =>
      await rust_storage.recordReadingSession(session: session);

  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) async =>
      await rust_storage.getReadingSessions(
        bookId: bookId, limit: BigInt.from(limit));

  Future<List<ReadingSession>> getRecentSessions(int limit) async =>
      await rust_storage.getRecentSessions(limit: BigInt.from(limit));

  Future<void> deleteSessionsByBook(String bookId) async =>
      await rust_storage.deleteSessionsByBook(bookId: bookId);

  // ==================== Stats ====================

  Future<GlobalStats> getGlobalReadingStats() async =>
      await rust_storage.getGlobalReadingStats();

  Future<List<ReadingStats>> getTodayReadingStats() async =>
      await rust_storage.getTodayReadingStats();

  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async =>
      await rust_storage.getReadingStatsRange(startDate: startDate, endDate: endDate);

  Future<void> updateDailyStats(ReadingStats stats) async =>
      await rust_storage.updateDailyStats(stats: stats);

  // ==================== Categories ====================

  Future<List<BookCategory>> getAllCategories() async =>
      await rust_storage.getAllCategories();

  Future<void> saveCategory(BookCategory category) async =>
      await rust_storage.saveCategory(category: category);

  Future<void> deleteCategory(String categoryId) async =>
      await rust_storage.deleteCategory(categoryId: categoryId);

  Future<BookCategory?> getCategory(String categoryId) async =>
      await rust_storage.getCategory(categoryId: categoryId);

  Future<List<BookCategory>> getCategoriesForBook(String bookId) async =>
      await rust_storage.getCategoriesForBook(bookId: bookId);

  Future<void> assignCategoryToBook(String bookId, String categoryId) async =>
      await rust_storage.assignCategoryToBook(bookId: bookId, categoryId: categoryId);

  Future<void> removeCategoryFromBook(String bookId, String categoryId) async =>
      await rust_storage.removeCategoryFromBook(bookId: bookId, categoryId: categoryId);

  Future<void> setCategoriesForBook(String bookId, List<String> categoryIds) async =>
      await rust_storage.setCategoriesForBook(bookId: bookId, categoryIds: categoryIds);

  Future<void> clearCategoriesForBook(String bookId) async =>
      await rust_storage.clearCategoriesForBook(bookId: bookId);

  // ==================== Layout Cache ====================

  // ==================== Notes ====================

  Future<Note> createNote(Note note) async => await rust_storage.createNote(note: note);

  Future<void> updateNote(Note note) async => await rust_storage.updateNote(note: note);

  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async =>
      await rust_storage.getNotes(bookId: bookId, noteType: noteType);

  Future<void> deleteNote(String noteId) async => await rust_storage.deleteNote(noteId: noteId);

  Future<void> deleteNotesByBook(String bookId) async => await rust_storage.deleteNotesByBook(bookId: bookId);

  Future<NoteStats> getNoteStats(String bookId) async => rust_storage.getNoteStats(bookId: bookId);

  // ==================== Database ====================

  Future<void> exportDatabase(String destPath) async =>
      await rust_storage.exportDatabase(destPath: destPath);

  Future<void> restoreDatabase(String backupPath) async =>
      await rust_storage.restoreDatabase(backupPath: backupPath);
}
