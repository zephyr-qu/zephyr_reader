library;

import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class MockRustStorageService implements RustStorageService {
  MockRustStorageService();

  final _books = <String, Book>{};
  final _chapters = <String, List<Chapter>>{};
  final _bookmarks = <String, List<Bookmark>>{};
  final _categories = <String, BookCategory>{};
  final _notes = <String, List<Note>>{};
  final _vocabWords = <String, VocabEntry>{};
  int _vocabCounter = 0;
  final _readingProgress = <String, ReadingProgress>{};
  ReadingProgress? lastSavedProgress;
  List<ReadingSession> recordedSessions = [];
  int getBookmarkStatsCallCount = 0;
  int getBookmarkStatsReturnValue = 0;

  // ==================== Books ====================

  @override
  Future<List<Book>> getAllBooks() async =>
      _books.values.toList()..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  @override
  Future<void> saveBook(Book book) async => _books[book.bookId] = book;

  @override
  Future<void> deleteBook(String bookId) async => _books.remove(bookId);

  @override
  Future<List<Book>> searchBooks(String keyword) async =>
      _books.values.where((b) => b.title.contains(keyword)).toList();

  @override
  Future<Book?> getBook(String bookId) async => _books[bookId];

  @override
  Future<List<Book>> getBooksByStatus(BookStatus status) async =>
      _books.values.where((b) => b.status == status).toList();

  @override
  Future<List<Book>> getPinnedBooks() async =>
      _books.values.where((b) => b.isPinned).toList();

  @override
  Future<List<Book>> getRecentlyReadBooks(int limit) async {
    final sorted = List<Book>.from(_books.values)
      ..sort(
        (a, b) => -(a.lastOpenedAt ?? DateTime(2000)).compareTo(
          b.lastOpenedAt ?? DateTime(2000),
        ),
      );
    return sorted.take(limit).toList();
  }

  @override
  Future<List<Book>> getBooksPaginated({
    required int limit,
    required int offset,
    String? sortBy,
    String? sortOrder,
  }) async {
    var list = _books.values.toList();
    if (sortBy == 'title') {
      list.sort((a, b) => a.title.compareTo(b.title));
    }
    if (sortOrder == 'desc') {
      list = list.reversed.toList();
    }
    return list.skip(offset).take(limit).toList();
  }

  @override
  Future<int> getBookCount() async => _books.length;

  @override
  Future<void> updateBookStatus(String bookId, BookStatus status) async {
    final book = _books[bookId];
    if (book != null) {
      _books[bookId] = book.copyWith(status: status);
    }
  }

  @override
  Future<void> updateBookPin(String bookId, bool isPinned) async {
    final book = _books[bookId];
    if (book != null) {
      _books[bookId] = book.copyWith(isPinned: isPinned);
    }
  }

  // ==================== Chapters ====================

  @override
  Future<List<Chapter>> getChaptersByBook(String bookId) async =>
      _chapters[bookId] ?? [];

  @override
  Future<void> saveChapters(String bookId, List<Chapter> chapters) async {
    _chapters[bookId] = chapters;
  }

  @override
  Future<void> deleteChaptersByBook(String bookId) async =>
      _chapters.remove(bookId);

  @override
  Future<Chapter?> getChapterByIndex(String bookId, int chapterIndex) async {
    final chapters = _chapters[bookId] ?? [];
    return chapters.where((c) => c.chapterIndex == chapterIndex).firstOrNull;
  }

  // ==================== Bookmarks ====================

  @override
  Future<List<Bookmark>> getBookmarks(String bookId) async =>
      _bookmarks[bookId] ?? [];

  @override
  Future<Bookmark?> getBookmark(String bookmarkId) async {
    for (final list in _bookmarks.values) {
      for (final bm in list) {
        if (bm.id == bookmarkId) return bm;
      }
    }
    return null;
  }

  @override
  Future<void> createBookmark(Bookmark bookmark) async {
    _bookmarks.putIfAbsent(bookmark.bookId, () => []);
    _bookmarks[bookmark.bookId]!.add(bookmark);
  }

  @override
  Future<void> deleteBookmark(String bookmarkId) async {
    for (final list in _bookmarks.values) {
      list.removeWhere((b) => b.id == bookmarkId);
    }
  }

  @override
  Future<void> deleteBookmarksByBook(String bookId) async =>
      _bookmarks.remove(bookId);

  @override
  Future<void> importBookmarks(List<Bookmark> bookmarks) async {
    for (final bm in bookmarks) {
      await createBookmark(bm);
    }
  }

  @override
  Future<List<Bookmark>> syncBookmarks(
    List<Bookmark> localBookmarks,
    List<Bookmark> remoteBookmarks,
  ) async {
    final merged = <String, Bookmark>{};
    for (final bm in localBookmarks) {
      merged[bm.id] = bm;
    }
    for (final bm in remoteBookmarks) {
      merged[bm.id] = bm;
    }
    return merged.values.toList();
  }

  @override
  Future<int> getBookmarkStats(String bookId) async {
    getBookmarkStatsCallCount++;
    return getBookmarkStatsReturnValue;
  }

  // ==================== Reading Progress ====================

  @override
  Future<ReadingProgress?> getReadingProgress(String bookId) async =>
      _readingProgress[bookId];

  @override
  Future<void> saveReadingProgress(ReadingProgress progress) async {
    _readingProgress[progress.bookId] = progress;
    lastSavedProgress = progress;
  }

  @override
  Future<void> clearReadingProgress(String bookId) async =>
      _readingProgress.remove(bookId);

  // ==================== Reading Sessions ====================

  @override
  Future<void> recordReadingSession(ReadingSession session) async {
    recordedSessions.add(session);
  }

  @override
  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) async =>
      recordedSessions.where((s) => s.bookId == bookId).take(limit).toList();

  @override
  Future<List<ReadingSession>> getRecentSessions(int limit) async =>
      recordedSessions.reversed.take(limit).toList();

  @override
  Future<void> deleteSessionsByBook(String bookId) async =>
      recordedSessions.removeWhere((s) => s.bookId == bookId);

  // ==================== Stats ====================

  GlobalStats? mockGlobalStats;
  List<ReadingStats> mockStatsRange = [];

  @override
  Future<GlobalStats> getGlobalReadingStats() async =>
      mockGlobalStats ??
      const GlobalStats(
        totalReadingTimeSeconds: 0,
        totalCharactersRead: 0,
        booksReadCount: 0,
        booksCompletedCount: 0,
        consecutiveReadingDays: 0,
        todayReadingTimeSeconds: 0,
        todayCharactersRead: 0,
        averageReadingSpeed: 0,
        totalBooksCount: 0,
        totalNotesCount: 0,
        totalBookmarksCount: 0,
      );

  @override
  Future<List<ReadingStats>> getTodayReadingStats() async => mockStatsRange;

  @override
  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async => mockStatsRange;

  @override
  Future<void> updateDailyStats(ReadingStats stats) async {}

  // ==================== Categories ====================

  @override
  Future<List<BookCategory>> getAllCategories() async =>
      _categories.values.toList();

  @override
  Future<void> saveCategory(BookCategory category) async =>
      _categories[category.id] = category;

  @override
  Future<void> deleteCategory(String categoryId) async =>
      _categories.remove(categoryId);

  @override
  Future<BookCategory?> getCategory(String categoryId) async =>
      _categories[categoryId];

  @override
  Future<List<BookCategory>> getCategoriesForBook(String bookId) async {
    return _categories.values.toList();
  }

  @override
  Future<void> assignCategoryToBook(String bookId, String categoryId) async {}

  @override
  Future<void> removeCategoryFromBook(String bookId, String categoryId) async {}

  @override
  Future<void> setCategoriesForBook(
    String bookId,
    List<String> categoryIds,
  ) async {}

  @override
  Future<void> clearCategoriesForBook(String bookId) async {}

  // ==================== Notes ====================

  @override
  Future<Note> createNote(Note note) async {
    _notes.putIfAbsent(note.bookId, () => []);
    _notes[note.bookId]!.add(note);
    return note;
  }

  @override
  Future<void> updateNote(Note note) async {
    final list = _notes[note.bookId];
    if (list != null) {
      final idx = list.indexWhere((n) => n.id == note.id);
      if (idx >= 0) list[idx] = note;
    }
  }

  @override
  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async {
    var list = _notes[bookId] ?? [];
    if (noteType != null) {
      list = list.where((n) => n.noteType == noteType).toList();
    }
    return list;
  }

  @override
  Future<List<Note>> getNotesInChapter(
    String bookId,
    int chapterIndex, {
    NoteType? noteType,
  }) async {
    var list = (_notes[bookId] ?? [])
        .where((n) => n.chapterIndex == chapterIndex)
        .toList();
    if (noteType != null) {
      list = list.where((n) => n.noteType == noteType).toList();
    }
    return list;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    for (final list in _notes.values) {
      list.removeWhere((n) => n.id == noteId);
    }
  }

  @override
  Future<void> deleteNotesByBook(String bookId) async => _notes.remove(bookId);

  final NoteStats _mockNoteStats = const NoteStats(
    totalCount: 0,
    highlightCount: 0,
    annotationCount: 0,
  );

  @override
  Future<NoteStats> getNoteStats(String bookId) async => _mockNoteStats;

  // ==================== Vocabulary ====================

  @override
  Future<VocabEntry> addVocabularyWord({
    required String word,
    required String pinyin,
    required String translation,
    String? contextSentence,
    String? bookId,
    int? chapterIndex,
    int? charOffset,
  }) async {
    _vocabCounter++;
    final entry = VocabEntry(
      id: 'vocab_$_vocabCounter',
      word: word,
      pinyin: pinyin,
      translation: translation,
      contextSentence: contextSentence,
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
      createdAt: DateTime.now(),
      reviewCount: 0,
      status: '',
    );
    _vocabWords[entry.id] = entry;
    return entry;
  }

  @override
  Future<List<VocabEntry>> getVocabularyWords({
    String? bookId,
    String? status,
  }) async {
    var list = _vocabWords.values.toList();
    if (bookId != null) {
      list = list.where((v) => v.bookId == bookId).toList();
    }
    if (status != null) {
      list = list.where((v) => v.status == status).toList();
    }
    return list;
  }

  @override
  Future<List<VocabEntry>> searchVocabulary(String query) async =>
      _vocabWords.values.where((v) => v.word.contains(query)).toList();

  @override
  Future<void> updateVocabularyStatus({
    required String id,
    required String status,
  }) async {
    final entry = _vocabWords[id];
    if (entry != null) {
      _vocabWords[id] = VocabEntry(
        id: entry.id,
        word: entry.word,
        pinyin: entry.pinyin,
        translation: entry.translation,
        contextSentence: entry.contextSentence,
        bookId: entry.bookId,
        chapterIndex: entry.chapterIndex,
        charOffset: entry.charOffset,
        createdAt: entry.createdAt,
        reviewCount: entry.reviewCount,
        lastReviewedAt: entry.lastReviewedAt,
        status: status,
      );
    }
  }

  @override
  Future<void> deleteVocabularyWord({required String id}) async =>
      _vocabWords.remove(id);

  final VocabStats _mockVocabStats = const VocabStats(
    totalWords: 0,
    learningCount: 0,
    knownCount: 0,
    masteredCount: 0,
  );

  @override
  Future<VocabStats> getVocabularyStats() async => _mockVocabStats;

  // ==================== Database ====================

  @override
  Future<void> exportDatabase(String destPath) async {}

  @override
  Future<void> restoreDatabase(String backupPath) async {}
}
