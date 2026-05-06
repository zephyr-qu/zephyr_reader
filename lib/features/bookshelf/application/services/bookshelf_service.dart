/// 书架业务服务
library;

import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/bookshelf_filter.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/chapter_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/bookmark_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/import_task.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import '../states/bookshelf_state.dart';

@injectable
class BookshelfService {
  final BookRepository _repository;
  final ChapterRepository _chapter;
  final BookmarkRepository _bookmark;
  final BookshelfState _state;

  BookshelfService(
    this._repository,
    this._state,
    this._chapter,
    this._bookmark,
  );

  Future<void> loadBooks() async {
    _state.isLoading.value = true;
    _state.error.value = null;

    try {
      final filter = _state.filter.value;
      List<DbBookRecord> books;

      // 利用 Rust 侧 API 进行过滤
      if (filter.keyword != null && filter.keyword!.isNotEmpty) {
        // 使用 Rust 侧关键词搜索
        books = await _repository.searchBooks(filter.keyword!);
      } else if (filter.status != null) {
        // 使用 Rust 侧状态筛选
        final targetStatus = DbBookStatus.values.firstWhere(
          (s) => s.name == filter.status,
          orElse: () => DbBookStatus.reading,
        );
        books = await _repository.getBooksByStatus(targetStatus);
      } else {
        // 获取全部书籍
        books = await _repository.getAllBooks();
      }

      // Dart 侧格式筛选（Rust 侧暂不支持）
      if (filter.format != null) {
        final targetFormat = DbBookFormat.values.firstWhere(
          (f) => f.name == filter.format,
          orElse: () => DbBookFormat.txt,
        );
        books = books.where((b) => b.format == targetFormat).toList();
      }

      // Dart 侧排序（Rust 侧暂不支持自定义排序）
      books.sort((a, b) {
        switch (filter.sortType) {
          case BookshelfSortType.lastRead:
            final aTime = a.lastOpenedAt ?? a.addedAt;
            final bTime = b.lastOpenedAt ?? b.addedAt;
            return filter.ascending
                ? aTime.compareTo(bTime)
                : bTime.compareTo(aTime);
          case BookshelfSortType.createdAt:
            return filter.ascending
                ? a.addedAt.compareTo(b.addedAt)
                : b.addedAt.compareTo(a.addedAt);
          case BookshelfSortType.title:
            return filter.ascending
                ? a.title.compareTo(b.title)
                : b.title.compareTo(a.title);
          case BookshelfSortType.author:
            return filter.ascending
                ? a.author.compareTo(b.author)
                : b.author.compareTo(a.title);
          case BookshelfSortType.progress:
            return filter.ascending
                ? a.chapterCount.compareTo(b.chapterCount)
                : b.chapterCount.compareTo(a.chapterCount);
        }
      });

      _state.setBooks(books);
    } catch (e) {
      _state.error.value = '加载书架失败';
      Logging.debug('BookshelfService.loadBooks error: $e');
    } finally {
      _state.isLoading.value = false;
    }
  }

  Future<DbBookRecord?> addBookFromImportTask(ImportTask task) async {
    if (task.status != ImportTaskStatus.completed) {
      Logging.debug('任务未完成，无法添加书籍');
      return null;
    }

    try {
      final existing = await _repository.getAllBooks();
      final exists = existing.any((b) => b.filePath == task.filePath);

      if (exists) {
        Logging.debug('书籍已存在：${task.filePath}');
        return existing.firstWhere((b) => b.filePath == task.filePath);
      }

      final book = DbBookRecord(
        bookId: 'book_${DateTime.now().millisecondsSinceEpoch}',
        title: task.title ?? task.fileName,
        author: task.author ?? '未知作者',
        filePath: task.filePath,
        format: _parseFormat(task.format),
        fileSize: task.fileSize,
        chapterCount: task.chapterCount ?? 0,
        totalCharacters: task.chapterCount ?? 0,
        coverPath: task.coverPath,
        description: null,
        addedAt: DateTime.now(),
        status: DbBookStatus.planned,
        isPinned: false,
      );

      await _repository.addBook(book);
      final newBook = await _repository.getBookById(book.bookId);

      if (newBook != null) {
        _state.addBook(newBook);
        await _saveChapters(newBook.bookId, task);
      }

      return newBook;
    } catch (e) {
      Logging.debug('BookshelfService.addBookFromImportTask error: $e');
      return null;
    }
  }

  DbBookFormat _parseFormat(String format) {
    switch (format.toLowerCase()) {
      case 'epub':
        return DbBookFormat.epub;
      case 'pdf':
        return DbBookFormat.pdf;
      default:
        return DbBookFormat.txt;
    }
  }

  Future<void> _saveChapters(String bookId, ImportTask task) async {
    if (task.chapterCount == 0 || task.chapters.isEmpty) {
      return;
    }

    try {
      final chapters = task.chapters.map((chapter) {
        return DbChapter(
          id: 'chapter_${chapter.index}',
          bookId: bookId,
          title: chapter.title,
          contentFile: task.filePath,
          chapterIndex: chapter.index,
          wordCount: 0,
          cachedAt: DateTime.now(),
          level: chapter.level,
        );
      }).toList();

      await _chapter.insertChapters(chapters);

      final book = await _repository.getBookById(bookId);
      if (book != null) {
        final updated = DbBookRecord(
          bookId: book.bookId,
          filePath: book.filePath,
          fileSize: book.fileSize,
          title: book.title,
          author: book.author,
          description: book.description,
          coverPath: book.coverPath,
          chapterCount: task.chapterCount ?? 0,
          totalCharacters: book.totalCharacters,
          format: book.format,
          addedAt: book.addedAt,
          lastOpenedAt: book.lastOpenedAt,
          status: book.status,
          isPinned: book.isPinned,
        );
        await _repository.updateBook(updated);
      }
    } catch (e) {
      Logging.debug('BookshelfService._saveChapters error: $e');
    }
  }

  Future<DbBookRecord?> addBook({
    required String title,
    required String author,
    required String filePath,
    required String fileFormat,
    int fileSize = 0,
    int totalChapters = 0,
    int totalCharacters = 0,
    String? coverPath,
    String? description,
  }) async {
    try {
      final existing = await _repository.getAllBooks();
      final exists = existing.any((b) => b.filePath == filePath);

      if (exists) {
        Logging.debug('书籍已存在：$filePath');
        return existing.firstWhere((b) => b.filePath == filePath);
      }

      final book = DbBookRecord(
        bookId: 'book_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        author: author,
        filePath: filePath,
        format: _parseFormat(fileFormat),
        fileSize: fileSize,
        chapterCount: totalChapters,
        totalCharacters: totalCharacters,
        coverPath: coverPath,
        description: description,
        addedAt: DateTime.now(),
        status: DbBookStatus.planned,
        isPinned: false,

      );

      await _repository.addBook(book);
      final newBook = await _repository.getBookById(book.bookId);

      if (newBook != null) {
        _state.addBook(newBook);
      }

      return newBook;
    } catch (e) {
      Logging.debug('BookshelfService.addBook error: $e');
      return null;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      await _repository.deleteBook(bookId);
      await _chapter.deleteChaptersByBookId(
        int.tryParse(bookId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      );
      await _bookmark.deleteBookmarksByBookId(bookId);

      if (book.coverPath != null) {
        try {
          final coverFile = File(book.coverPath!);
          if (await coverFile.exists()) {
            await coverFile.delete();
          }
        } catch (e) {
          Logging.debug('删除封面文件失败：$e');
        }
      }

      _state.removeBook(bookId);
      return true;
    } catch (e) {
      Logging.debug('BookshelfService.deleteBook error: $e');
      return false;
    }
  }

  Future<int> deleteBooks(List<String> bookIds) async {
    int deletedCount = 0;
    for (final bookId in bookIds) {
      if (await deleteBook(bookId)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  Future<bool> updateBookTitle(String bookId, String newTitle) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      final updated = DbBookRecord(
        bookId: book.bookId,
        filePath: book.filePath,
        fileSize: book.fileSize,
        title: newTitle,
        author: book.author,
        description: book.description,
        coverPath: book.coverPath,
        chapterCount: book.chapterCount,
        totalCharacters: book.totalCharacters,
        format: book.format,
        addedAt: book.addedAt,
        lastOpenedAt: book.lastOpenedAt,
        status: book.status,
        isPinned: book.isPinned,
      );
      await _repository.updateBook(updated);

      final books = _state.books.value;
      final index = books.indexWhere((b) => b.bookId == bookId);
      if (index != -1) {
        _state.updateBook(updated);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateBookTitle error: $e');
      return false;
    }
  }

  Future<bool> updateBookStatus(String bookId, String status) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      final bookStatus = DbBookStatus.values.firstWhere(
        (s) => s.name == status,
        orElse: () => DbBookStatus.planned,
      );

      final updated = DbBookRecord(
        bookId: book.bookId,
        filePath: book.filePath,
        fileSize: book.fileSize,
        title: book.title,
        author: book.author,
        description: book.description,
        coverPath: book.coverPath,
        chapterCount: book.chapterCount,
        totalCharacters: book.totalCharacters,
        format: book.format,
        addedAt: book.addedAt,
        lastOpenedAt: book.lastOpenedAt,
        status: bookStatus,
        isPinned: book.isPinned,

      );
      await _repository.updateBook(updated);

      final books = _state.books.value;
      final index = books.indexWhere((b) => b.bookId == bookId);
      if (index != -1) {
        _state.updateBook(updated);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateBookStatus error: $e');
      return false;
    }
  }

  Future<bool> updateReadingProgress({
    required String bookId,
    required String chapterId,
    required int currentPage,
    required int totalPages,
    required double progress,
  }) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      final updated = DbBookRecord(
        bookId: book.bookId,
        filePath: book.filePath,
        fileSize: book.fileSize,
        title: book.title,
        author: book.author,
        description: book.description,
        coverPath: book.coverPath,
        chapterCount: book.chapterCount,
        totalCharacters: book.totalCharacters,
        format: book.format,
        addedAt: book.addedAt,
        lastOpenedAt: book.lastOpenedAt,
        status: book.status,
        isPinned: book.isPinned,

      );
      await _repository.updateBook(updated);

      final books = _state.books.value;
      final index = books.indexWhere((b) => b.bookId == bookId);
      if (index != -1) {
        _state.updateBook(updated);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateReadingProgress error: $e');
      return false;
    }
  }

  Future<DbBookRecord?> getBookDetail(String bookId) async {
    return await _repository.getBookById(bookId);
  }

  Future<List<DbChapter>> getBookChapters(String bookId) async {
    return await _chapter.getChaptersByBookId(bookId.hashCode);
  }

  Future<void> refresh() async {
    await loadBooks();
  }
}
