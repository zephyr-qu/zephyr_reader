import 'package:zephyr_reader/src/rust/storage/models.dart';

Book createTestBook({
  String id = 'book_1',
  String title = '测试书籍',
  String author = '测试作者',
  int chapterCount = 3,
  BookStatus status = BookStatus.reading,
  bool isPinned = false,
  int fileSize = 1000,
  int totalChars = 50000,
}) {
  return Book(
    bookId: id,
    filePath: '/test/books/$id.txt',
    fileSize: fileSize,
    title: title,
    author: author,
    chapterCount: chapterCount,
    totalCharacters: totalChars,
    format: BookFormat.txt,
    addedAt: DateTime(2026, 1, 1),
    lastOpenedAt: DateTime(2026, 5, 18),
    status: status,
    isPinned: isPinned,
  );
}

Chapter createTestChapter({
  String id = 'chapter_0',
  String bookId = 'book_1',
  String title = '第一章',
  int chapterIndex = 0,
  int contentLength = 1000,
  int startIndex = 0,
  int endIndex = 1000,
}) {
  return Chapter(
    id: id,
    bookId: bookId,
    title: title,
    contentFile: '/test/books/book_1.txt',
    chapterIndex: chapterIndex,
    wordCount: contentLength ~/ 5,
    cachedAt: DateTime.now(),
    level: 1,
    startIndex: startIndex,
    endIndex: endIndex,
    contentLength: contentLength,
  );
}

Bookmark createTestBookmark({
  String id = 'bm_1',
  String bookId = 'book_1',
  int chapterIndex = 0,
  int charOffset = 100,
  String title = '测试书签',
}) {
  return Bookmark(
    id: id,
    bookId: bookId,
    chapterIndex: chapterIndex,
    charOffset: charOffset,
    title: title,
    createdAt: DateTime(2026, 5, 18),
  );
}

Note createTestNote({
  String id = 'note_1',
  String bookId = 'book_1',
  int chapterIndex = 0,
  int charOffset = 50,
  int length = 20,
  NoteType noteType = NoteType.highlight,
  String content = '测试高亮',
  int? highlightColor = 0xFFFFEB3B,
}) {
  return Note(
    id: id,
    bookId: bookId,
    chapterIndex: chapterIndex,
    charOffset: charOffset,
    length: length,
    noteType: noteType,
    content: content,
    selectedText: content,
    highlightColor: highlightColor,
    createdAt: DateTime(2026, 5, 18),
    updatedAt: DateTime(2026, 5, 18),
  );
}

BookCategory createTestCategory({
  String id = 'cat_1',
  String name = '小说',
  String color = '#FF5722',
  bool isSystem = false,
}) {
  return BookCategory(
    id: id,
    name: name,
    color: color,
    sortOrder: 0,
    isSystem: isSystem,
    createdAt: DateTime(2026, 1, 1),
  );
}

ReadingSession createTestSession({
  String id = 'session_1',
  String bookId = 'book_1',
  int chapterIndex = 0,
  int startCharOffset = 0,
  int endCharOffset = 500,
  int durationSeconds = 300,
}) {
  final now = DateTime.now();
  return ReadingSession(
    id: id,
    bookId: bookId,
    chapterIndex: chapterIndex,
    startCharOffset: startCharOffset,
    endCharOffset: endCharOffset,
    startedAt: now.subtract(Duration(seconds: durationSeconds)),
    endedAt: now,
    durationSeconds: durationSeconds,
  );
}

VocabEntry createTestVocabEntry({
  String id = 'vocab_1',
  String word = 'abandon',
  String translation = '放弃',
  String status = 'learning',
}) {
  return VocabEntry(
    id: id,
    word: word,
    pinyin: 'fàng qì',
    translation: translation,
    createdAt: DateTime(2026, 5, 18),
    reviewCount: 0,
    status: status,
  );
}

List<ReadingStats> createTestDailyStats({
  int days = 7,
  int secondsPerDay = 1800,
  int charsPerDay = 5000,
}) {
  final now = DateTime.now();
  return List.generate(days, (i) {
    final date = now.subtract(Duration(days: days - 1 - i));
    return ReadingStats(
      bookId: 'book_1',
      date:
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      readingTimeSeconds: secondsPerDay,
      charactersRead: charsPerDay,
      sessionCount: 2,
    );
  });
}

const String testChapterContent = '''
第一章
这是测试书籍的第一章内容。这里有一些中文文本用于测试阅读功能。

第二天，他继续阅读这本书。这是一个很好的故事，讲述了关于知识的力量。

在阅读过程中，用户可以标记重点、添加笔记，并且可以查看生词解释。

第三章
这是最后一章。故事在这里结束，主人公学到了很多知识。
''';
