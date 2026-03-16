/// 数据模型转换器
///
/// 提供不同层之间数据模型的转换方法
library;

import 'domain/models/book.dart';
import 'domain/models/chapter.dart';
import 'domain/models/bookmark.dart';

/// 模型转换器
class ModelMapper {
  // ==================== Book 转换 ====================

  /// 数据库 Book -> 领域 Book
  static Book bookFromDb(dynamic dbBook) {
    return Book.fromDb(dbBook);
  }

  /// 领域 Book -> 数据库 Book (返回 Map，需要手动创建 Companion)
  static Map<String, dynamic> bookToDbMap(Book book) {
    return {
      'id': int.tryParse(book.id) ?? 0,
      'title': book.title,
      'author': book.author,
      'coverPath': book.coverPath,
      'description': book.description,
      'filePath': book.filePath,
      'fileFormat': book.fileType,
      'fileSize': book.fileSize,
      'totalChapters': book.chapterCount,
      'totalCharacters': book.totalCharacters,
      'currentChapterId': book.currentChapterId,
      'currentPageIndex': book.currentPageIndex,
      'totalPages': book.totalPages,
      'progress': book.progress,
      'status': book.status,
      'isPinned': book.isPinned,
      'createdAt': book.createdAt,
      'updatedAt': book.updatedAt,
      'lastReadAt': book.lastReadAt,
    };
  }

  /// Rust BookInfo -> 领域 Book
  static Book bookFromRust(dynamic rustBookInfo) {
    return Book.fromRust(rustBookInfo);
  }

  // ==================== Chapter 转换 ====================

  /// 数据库 Chapter -> 领域 Chapter
  static Chapter chapterFromDb(dynamic dbChapter) {
    return Chapter.fromDb(dbChapter);
  }

  /// 领域 Chapter -> 数据库 Chapter
  static Map<String, dynamic> chapterToDbMap(Chapter chapter) {
    return {
      'id': chapter.id,
      'bookId': int.tryParse(chapter.bookId) ?? 0,
      'title': chapter.title,
      'contentFile': chapter.contentFile,
      'chapterIndex': chapter.chapterIndex,
      'wordCount': chapter.wordCount,
      'cachedAt': chapter.cachedAt ?? DateTime.now(),
    };
  }

  /// Rust ChapterInfo -> 领域 Chapter
  static Chapter chapterFromRust(dynamic rustChapterInfo, String bookId) {
    return Chapter.fromRust(rustChapterInfo, bookId);
  }

  // ==================== Bookmark 转换 ====================

  /// 数据库 Bookmark -> 领域 BookmarkItem
  static BookmarkItem bookmarkFromDb(dynamic dbBookmark) {
    return BookmarkItem.fromDb(dbBookmark);
  }

  /// 领域 BookmarkItem -> 数据库 Bookmark
  static Map<String, dynamic> bookmarkToDbMap(BookmarkItem bookmark) {
    return {
      'id': int.tryParse(bookmark.id) ?? 0,
      'bookId': int.tryParse(bookmark.bookId) ?? 0,
      'chapterId': bookmark.chapterId,
      'position': bookmark.position,
      'note': bookmark.note,
      'createdAt': bookmark.createdAt,
    };
  }

  /// Rust Bookmark -> 领域 BookmarkItem
  static BookmarkItem bookmarkFromRust(dynamic rustBookmark) {
    return BookmarkItem.fromRust(rustBookmark);
  }

  // ==================== 列表转换 ====================

  /// 数据库 Book 列表 -> 领域 Book 列表
  static List<Book> booksFromDbList(List<dynamic> dbBooks) {
    return dbBooks.map((dbBook) => Book.fromDb(dbBook)).toList();
  }

  /// 数据库 Chapter 列表 -> 领域 Chapter 列表
  static List<Chapter> chaptersFromDbList(List<dynamic> dbChapters) {
    return dbChapters.map((dbChapter) => Chapter.fromDb(dbChapter)).toList();
  }

  /// 数据库 Bookmark 列表 -> 领域 BookmarkItem 列表
  static List<BookmarkItem> bookmarksFromDbList(List<dynamic> dbBookmarks) {
    return dbBookmarks
        .map((dbBookmark) => BookmarkItem.fromDb(dbBookmark))
        .toList();
  }
}
