import 'package:uuid/uuid.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// ===== UUID helper =====
const _uuid = Uuid();

/// 创建测试用 Book 对象
///
/// 所有 `PlatformInt64` 字段（如 fileSize, charOffset）在 Dart 侧实际为 `int`，
/// 直接使用 `int` 类型赋值即可。
Book createTestBook({
  String? bookId,
  String title = 'Test Book',
  String? author = 'Test Author',
  String filePath = '/test/books/book_1.txt',
  int fileSize = 1024,
  DateTime? addedAt,
  DateTime? lastOpenedAt,
  String? publisher,
  String? translator,
  String? isbn,
  String? description,
  String? coverPath,
}) {
  return Book(
    bookId: bookId ?? _uuid.v4(),
    filePath: filePath,
    fileHash: null,
    fileSize: fileSize,
    fileMtime: null,
    title: title,
    author: author,
    coverPath: coverPath,
    chapterCount: 10,
    totalCharacters: 50000,
    format: BookFormat.txt,
    addedAt: addedAt ?? DateTime.now(),
    lastOpenedAt: lastOpenedAt,
    status: BookStatus.planned,
    isPinned: false,
    description: description,
    publisher: publisher,
    translator: translator,
    isbn: isbn,
  );
}

/// 批量创建测试书籍
List<Book> createTestBooks({int count = 10}) {
  return List.generate(
    count,
    (i) => createTestBook(
      bookId: 'book_$i',
      title: 'Book Title $i',
      author: i % 2 == 0 ? 'Author A' : 'Author B',
    ),
  );
}

/// 创建测试用 Chapter 对象
Chapter createTestChapter({
  String? id,
  String bookId = 'test_book_1',
  String title = 'Test Chapter',
  int chapterIndex = 0,
  int level = 0,
}) {
  return Chapter(
    id: id ?? _uuid.v4(),
    bookId: bookId,
    title: title,
    chapterIndex: chapterIndex,
    wordCount: 5000,
    cachedAt: DateTime.now(),
    level: level,
    startIndex: 0,
    endIndex: 5000,
    contentLength: 5000,
  );
}

/// 批量创建测试章节
List<Chapter> createTestChapters({
  String bookId = 'test_book_1',
  int count = 5,
}) {
  return List.generate(
    count,
    (i) =>
        createTestChapter(bookId: bookId, chapterIndex: i, title: '第${i + 1}章'),
  );
}

/// 创建测试用 Bookmark 对象
Bookmark createTestBookmark({
  String? id,
  String bookId = 'test_book_1',
  int chapterIndex = 0,
  int charOffset = 0,
  String? title,
  DateTime? createdAt,
}) {
  return Bookmark(
    id: id ?? _uuid.v4(),
    bookId: bookId,
    chapterIndex: chapterIndex,
    charOffset: charOffset,
    title: title ?? '第${chapterIndex + 1}章',
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// 创建测试用 Category 对象
Category createTestCategory({
  String? id,
  String name = 'Test Category',
  String? description,
  String color = '#FF5722',
  int sortOrder = 0,
}) {
  return Category(
    id: id ?? _uuid.v4(),
    name: name,
    description: description,
    color: color,
    sortOrder: sortOrder,
    isSystem: false,
  );
}

/// 创建测试用 Vocab 对象
Vocab createTestVocab({
  String? id,
  String word = 'test',
  String? contextSentence,
  String? bookId,
  VocabStatus status = VocabStatus.unstarted,
  DateTime? createdAt,
}) {
  return Vocab(
    id: id ?? _uuid.v4(),
    word: word,
    pinyin: 'test_pinyin',
    translation: 'test_translation',
    contextSentence: contextSentence,
    bookId: bookId,
    chapterIndex: null,
    charOffset: null,
    createdAt: createdAt ?? DateTime.now(),
    reviewCount: 0,
    lastReviewedAt: null,
    status: status,
    wordList: null,
    dictSource: null,
    dictEntryHash: null,
  );
}

/// 批量创建测试生词
List<Vocab> createTestVocabs({int count = 20}) {
  final words = ['apple', 'banana', 'cherry', 'date', 'elderberry'];
  return List.generate(
    count,
    (i) => createTestVocab(
      word: words[i % words.length],
      status: i < 5 ? VocabStatus.learning : VocabStatus.unstarted,
    ),
  );
}

/// 创建测试用 Note 对象
Note createTestNote({
  String? id,
  String bookId = 'test_book_1',
  int chapterIndex = 0,
  int charOffset = 0,
  int length = 4,
  NoteType noteType = NoteType.highlight,
  String content = '测试笔记内容',
  String? selectedText,
  DateTime? createdAt,
}) {
  return Note(
    id: id ?? _uuid.v4(),
    bookId: bookId,
    chapterIndex: chapterIndex,
    charOffset: charOffset,
    length: length,
    noteType: noteType,
    content: content,
    selectedText: selectedText ?? '测试文本',
    highlightColor: null,
    pairedNoteId: null,
    language: null,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/// 批量创建测试笔记
List<Note> createTestNotes({String bookId = 'test_book_1', int count = 15}) {
  final types = [NoteType.highlight, NoteType.annotation];
  return List.generate(
    count,
    (i) => createTestNote(
      bookId: bookId,
      chapterIndex: i % 5,
      noteType: types[i % types.length],
    ),
  );
}

// ===== Reader 相关测试数据 =====

/// 测试用的章节内容
const String testChapterContent = '''
这是一段测试章节内容。
它包含多行文本，用于模拟真实的章节内容。
每行文字都有一定的字符数，方便测试阅读进度和分页功能。
测试数据应该尽可能接近实际情况，以确保测试的有效性。
最后一行测试数据结束。
''';

/// 创建测试用的文章数据
Map<String, dynamic> createTestArticle({
  String id = 'article_1',
  String title = '测试文章',
  String content = '这是文章内容',
}) {
  return {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': DateTime.now(),
  };
}

/// 创建测试用的阅读统计
Map<String, dynamic> createTestReadingStats({
  int readMinutes = 30,
  int pagesRead = 10,
  DateTime? date,
}) {
  return {
    'readMinutes': readMinutes,
    'pagesRead': pagesRead,
    'date': date ?? DateTime.now(),
  };
}

/// 创建测试用的书签列表
List<Bookmark> createTestBookmarkList({int count = 5}) {
  return List.generate(
    count,
    (i) => createTestBookmark(chapterIndex: i, charOffset: i * 100),
  );
}

/// 创建测试用的章节列表
List<Chapter> createTestChapterList({int count = 10}) {
  return List.generate(count, (i) => createTestChapter(chapterIndex: i));
}
