library;

import 'package:zephyr_reader/src/rust/api/bilingual.dart' as rust_bilingual;
import 'package:zephyr_reader/src/rust/api/book.dart' as rust_book;
import 'package:zephyr_reader/src/rust/api/cover.dart' as rust_cover;
import 'package:zephyr_reader/src/rust/api/epub.dart' as rust_epub;
import 'package:zephyr_reader/src/rust/api/file.dart' as rust_file;
import 'package:zephyr_reader/src/rust/api/search.dart' as rust_search;
import 'package:zephyr_reader/src/rust/api/storage.dart' as rust_storage;
import 'package:zephyr_reader/src/rust/api/typeset.dart' as rust_typeset;
import 'package:zephyr_reader/src/rust/api/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/domain/parser.dart';
import 'package:zephyr_reader/src/rust/text/pagination.dart';
import 'package:zephyr_reader/src/rust/api.dart' as api;

/// 统一 Rust FFI 桥接层
///
/// 合并所有 Rust 服务包装类，提供单一注入点。
/// 旧的服务类（RustStorageService, RustCoreService 等）保留为薄包装，
/// 新代码应直接使用此类。
class RustBridge {
  // ==================== Connection ====================
  String testConnection() => api.testConnection();

  // ==================== Books ====================

  Future<List<Book>> getAllBooks() async => rust_storage.getAllBooks();
  Future<void> saveBook(Book book) async => rust_storage.saveBook(book: book);
  Future<void> deleteBook(String bookId) async =>
      rust_storage.deleteBook(bookId: bookId);
  Future<List<Book>> searchBooks(String keyword) async =>
      rust_storage.searchBooks(keyword: keyword);
  Future<Book?> getBook(String bookId) async =>
      rust_storage.getBook(bookId: bookId);
  Future<List<Book>> getBooksByStatus(BookStatus status) async =>
      rust_storage.getBooksByStatus(status: status);
  Future<List<Book>> getPinnedBooks() async => rust_storage.getPinnedBooks();
  Future<List<Book>> getRecentlyReadBooks(int limit) async =>
      rust_storage.getRecentlyReadBooks(limit: BigInt.from(limit));
  Future<List<Book>> getBooksPaginated({
    required int limit,
    required int offset,
    String? sortBy,
    String? sortOrder,
  }) async => rust_storage.getBooksPaginated(
    limit: limit,
    offset: offset,
    sortBy: sortBy,
    sortOrder: sortOrder,
  );
  Future<int> getBookCount() async =>
      (await rust_storage.getBookCount()).toInt();
  Future<void> updateBookStatus(String bookId, BookStatus status) async =>
      rust_storage.updateBookStatus(bookId: bookId, status: status);
  Future<void> updateBookPin(String bookId, bool isPinned) async =>
      rust_storage.updateBookPin(bookId: bookId, isPinned: isPinned);

  // ==================== Chapters ====================

  Future<List<Chapter>> getChaptersByBook(String bookId) async =>
      rust_storage.getChaptersByBook(bookId: bookId);
  Future<void> saveChapters(String bookId, List<Chapter> chapters) async =>
      rust_storage.saveChapters(bookId: bookId, chapters: chapters);
  Future<void> deleteChaptersByBook(String bookId) async =>
      rust_storage.deleteChaptersByBook(bookId: bookId);
  Future<Chapter?> getChapterByIndex(String bookId, int chapterIndex) async =>
      rust_storage.getChapterByIndex(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );

  // ==================== Bookmarks ====================

  Future<List<Bookmark>> getBookmarks(String bookId) async =>
      rust_storage.getBookmarks(bookId: bookId);
  Future<Bookmark?> getBookmark(String bookmarkId) async =>
      rust_storage.getBookmark(bookmarkId: bookmarkId);
  Future<void> createBookmark(Bookmark bookmark) async =>
      rust_storage.createBookmark(bookmark: bookmark);
  Future<void> deleteBookmark(String bookmarkId) async =>
      rust_storage.deleteBookmark(bookmarkId: bookmarkId);
  Future<void> deleteBookmarksByBook(String bookId) async =>
      rust_storage.deleteBookmarksByBook(bookId: bookId);
  Future<void> importBookmarks(List<Bookmark> bookmarks) async =>
      rust_storage.importBookmarks(bookmarks: bookmarks);
  Future<List<Bookmark>> syncBookmarks(
    List<Bookmark> localBookmarks,
    List<Bookmark> remoteBookmarks,
  ) async => rust_storage.syncBookmarks(
    localBookmarks: localBookmarks,
    remoteBookmarks: remoteBookmarks,
  );
  Future<int> getBookmarkStats(String bookId) async =>
      rust_storage.getBookmarkStats(bookId: bookId);

  // ==================== Reading Progress ====================

  Future<ReadingProgress?> getReadingProgress(String bookId) async =>
      rust_storage.getReadingProgress(bookId: bookId);
  Future<void> saveReadingProgress(ReadingProgress progress) async =>
      rust_storage.saveReadingProgress(progress: progress);
  Future<void> clearReadingProgress(String bookId) async =>
      rust_storage.clearReadingProgress(bookId: bookId);

  // ==================== Reading Sessions ====================

  Future<void> recordReadingSession(ReadingSession session) async =>
      rust_storage.recordReadingSession(session: session);
  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) async => rust_storage.getReadingSessions(
    bookId: bookId,
    limit: BigInt.from(limit),
  );
  Future<List<ReadingSession>> getRecentSessions(int limit) async =>
      rust_storage.getRecentSessions(limit: BigInt.from(limit));
  Future<void> deleteSessionsByBook(String bookId) async =>
      rust_storage.deleteSessionsByBook(bookId: bookId);

  // ==================== Stats ====================

  Future<GlobalStats> getGlobalReadingStats() async =>
      rust_storage.getGlobalReadingStats();
  Future<List<ReadingStats>> getTodayReadingStats() async =>
      rust_storage.getTodayReadingStats();
  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async =>
      rust_storage.getReadingStatsRange(startDate: startDate, endDate: endDate);
  Future<void> updateDailyStats(ReadingStats stats) async =>
      rust_storage.updateDailyStats(stats: stats);

  // ==================== Categories ====================

  Future<List<BookCategory>> getAllCategories() async =>
      rust_storage.getAllCategories();
  Future<void> saveCategory(BookCategory category) async =>
      rust_storage.saveCategory(category: category);
  Future<void> deleteCategory(String categoryId) async =>
      rust_storage.deleteCategory(categoryId: categoryId);
  Future<BookCategory?> getCategory(String categoryId) async =>
      rust_storage.getCategory(categoryId: categoryId);
  Future<List<BookCategory>> getCategoriesForBook(String bookId) async =>
      rust_storage.getCategoriesForBook(bookId: bookId);
  Future<void> assignCategoryToBook(String bookId, String categoryId) async =>
      rust_storage.assignCategoryToBook(bookId: bookId, categoryId: categoryId);
  Future<void> removeCategoryFromBook(String bookId, String categoryId) async =>
      rust_storage.removeCategoryFromBook(
        bookId: bookId,
        categoryId: categoryId,
      );
  Future<void> setCategoriesForBook(
    String bookId,
    List<String> categoryIds,
  ) async => rust_storage.setCategoriesForBook(
    bookId: bookId,
    categoryIds: categoryIds,
  );
  Future<void> clearCategoriesForBook(String bookId) async =>
      rust_storage.clearCategoriesForBook(bookId: bookId);

  // ==================== Notes ====================

  Future<Note> createNote(Note note) async =>
      rust_storage.createNote(note: note);
  Future<void> updateNote(Note note) async =>
      rust_storage.updateNote(note: note);
  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async =>
      rust_storage.getNotes(bookId: bookId, noteType: noteType);
  Future<List<Note>> getNotesInChapter(
    String bookId,
    int chapterIndex, {
    NoteType? noteType,
  }) async => rust_storage.getNotesInChapter(
    bookId: bookId,
    chapterIndex: chapterIndex,
    noteType: noteType,
  );
  Future<void> deleteNote(String noteId) async =>
      rust_storage.deleteNote(noteId: noteId);
  Future<void> deleteNotesByBook(String bookId) async =>
      rust_storage.deleteNotesByBook(bookId: bookId);
  Future<NoteStats> getNoteStats(String bookId) async =>
      rust_storage.getNoteStats(bookId: bookId);

  // ==================== Vocabulary ====================

  Future<VocabEntry> addVocabularyWord({
    required String word,
    required String pinyin,
    required String translation,
    String? contextSentence,
    String? bookId,
    int? chapterIndex,
    int? charOffset,
  }) async => rust_vocab.addVocabularyWord(
    word: word,
    pinyin: pinyin,
    translation: translation,
    contextSentence: contextSentence,
    bookId: bookId,
    chapterIndex: chapterIndex,
    charOffset: charOffset,
  );
  Future<List<VocabEntry>> getVocabularyWords({
    String? bookId,
    String? status,
  }) async => rust_vocab.getVocabularyWords(bookId: bookId, status: status);
  Future<List<VocabEntry>> searchVocabulary(String query) async =>
      rust_vocab.searchVocabulary(query: query);
  Future<void> updateVocabularyStatus({
    required String id,
    required String status,
  }) async => rust_vocab.updateVocabularyStatus(id: id, status: status);
  Future<void> deleteVocabularyWord({required String id}) async =>
      rust_vocab.deleteVocabularyWord(id: id);
  Future<VocabStats> getVocabularyStats() async =>
      rust_vocab.getVocabularyStats();

  // ==================== Format detection ====================

  List<String> getSupportedFormats() => rust_book.getSupportedFormats();
  bool supportsFormat(String format) =>
      rust_book.supportsFormat(format: format);

  // ==================== Book parsing ====================

  Future<ParseResult> parseBook(String filePath) async =>
      rust_book.parseBook(filePath: filePath);
  Future<BookMetadata> extractMetadata(String filePath) async =>
      rust_book.extractMetadata(filePath: filePath);
  Future<ChapterContent> getChapter(
    String filePath,
    int chapterIndex, {
    TypesetConfig? config,
  }) async => rust_book.getChapter(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  // ==================== Pagination ====================

  Future<List<PageContent>> paginateAllContent(
    String filePath,
    int chapterIndex,
    TypesetConfig config,
  ) async => rust_book.paginateAllContent(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );
  Future<PageStreamer> createPageStreamer(
    String filePath,
    int chapterIndex,
    TypesetConfig config,
  ) async => rust_book.createPageStreamer(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  // ==================== Typesetting ====================

  Future<String> typesetText(String content, TypesetConfig config) async =>
      rust_typeset.typesetText(content: content, config: config);

  // ==================== File operations ====================

  Future<int> getFileSize(String filePath) async =>
      rust_file.getFileSize(filePath: filePath);
  Future<String> readFileChunk(
    String filePath,
    int startPos,
    int chunkSize,
  ) async => rust_file.readFileChunk(
    filePath: filePath,
    startPos: startPos,
    chunkSize: chunkSize,
  );

  // ==================== Cover extraction ====================

  Future<String> extractBookCover({
    required String filePath,
    required String outputDir,
  }) async =>
      rust_cover.extractBookCover(filePath: filePath, outputDir: outputDir);
  bool supportsCoverExtraction(String filePath) =>
      rust_cover.supportsCoverExtraction(filePath: filePath);

  // ==================== EPUB ====================

  Future<EpubMetadata> getEpubMetadata(String filePath) async =>
      rust_epub.getEpubMetadata(filePath: filePath);
  Future<List<RichParagraph>> getEpubChapterRichContent({
    required String filePath,
    required int chapterIndex,
    required TypesetConfig config,
  }) async => rust_epub.getEpubChapterRichContent(
    filePath: filePath,
    chapterIndex: chapterIndex,
    config: config,
  );

  // ==================== Bilingual ====================

  Future<BilingualAlignment> alignBilingualContent({
    required String chineseContent,
    required String englishContent,
    double minSimilarity = 0.5,
  }) async => rust_bilingual.alignBilingualContent(
    chineseContent: chineseContent,
    englishContent: englishContent,
    minSimilarity: minSimilarity,
  );
  Future<BilingualAlignment> simpleBilingualAlign({
    required String chineseContent,
    required String englishContent,
  }) async => rust_bilingual.simpleBilingualAlign(
    chineseContent: chineseContent,
    englishContent: englishContent,
  );

  // ==================== Search ====================

  Future<void> initSearchEngine() async => rust_search.initSearchEngine();
  Future<void> indexChapterContent({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) async => rust_search.indexChapterContent(
    bookId: bookId,
    chapterId: chapterId,
    chapterTitle: chapterTitle,
    content: content,
  );
  Future<List<SearchResult>> searchInBook({
    required String bookId,
    required String query,
    required int limit,
  }) async =>
      rust_search.searchInBook(bookId: bookId, query: query, limit: limit);
  Future<void> clearAllSearchIndex() async => rust_search.clearAllSearchIndex();
  Future<void> deleteBookSearchIndex(String bookId) async =>
      rust_search.deleteBookSearchIndex(bookId: bookId);

  // ==================== Database ====================

  Future<void> exportDatabase(String destPath) async =>
      rust_storage.exportDatabase(destPath: destPath);
  Future<void> restoreDatabase(String backupPath) async =>
      rust_storage.restoreDatabase(backupPath: backupPath);
}
