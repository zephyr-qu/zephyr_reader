/// 书架业务服务
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/domain/models/chapter.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/bookshelf_filter.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/chapter_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/bookmark_repository.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/import_task.dart';
import '../states/bookshelf_state.dart';

/// 书架业务服务
///
/// 负责书架相关的业务逻辑，包括：
/// - 书籍列表加载、筛选、排序
/// - 书籍导入与解析
/// - 书籍删除与文件清理
/// - 阅读进度更新
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

  /// 加载书架书籍列表
  Future<void> loadBooks() async {
    _state.isLoading.value = true;
    _state.error.value = null;

    try {
      final books = await _repository.getAllBooks();

      // 在内存中排序和筛选
      var filteredBooks = books;
      final filter = _state.filter.value;

      // 筛选
      if (filter.keyword != null && filter.keyword!.isNotEmpty) {
        final keyword = filter.keyword!.toLowerCase();
        filteredBooks = filteredBooks
            .where(
              (b) =>
                  b.title.toLowerCase().contains(keyword) ||
                  b.author.toLowerCase().contains(keyword),
            )
            .toList();
      }

      if (filter.status != null) {
        filteredBooks = filteredBooks
            .where((b) => b.status == filter.status)
            .toList();
      }

      if (filter.format != null) {
        filteredBooks = filteredBooks
            .where((b) => b.fileType == filter.format)
            .toList();
      }

      // 排序
      filteredBooks.sort((a, b) {
        switch (filter.sortType) {
          case BookshelfSortType.lastRead:
            final aTime = a.lastReadAt ?? a.createdAt;
            final bTime = b.lastReadAt ?? b.createdAt;
            return filter.ascending
                ? aTime.compareTo(bTime)
                : bTime.compareTo(aTime);
          case BookshelfSortType.createdAt:
            return filter.ascending
                ? a.createdAt.compareTo(b.createdAt)
                : b.createdAt.compareTo(a.createdAt);
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
                ? a.progress.compareTo(b.progress)
                : b.progress.compareTo(a.progress);
        }
      });

      _state.setBooks(filteredBooks);
    } catch (e) {
      _state.error.value = '加载书架失败';
      Logging.debug('BookshelfService.loadBooks error: $e');
    } finally {
      _state.isLoading.value = false;
    }
  }

  /// 添加书籍到书架（从导入任务）
  Future<Book?> addBookFromImportTask(ImportTask task) async {
    if (task.status != ImportTaskStatus.completed) {
      Logging.debug('任务未完成，无法添加书籍');
      return null;
    }

    try {
      // 检查是否已存在（通过文件路径）
      final existing = await _repository.getAllBooks();
      final exists = existing.any((b) => b.filePath == task.filePath);

      if (exists) {
        Logging.debug('书籍已存在：${task.filePath}');
        return existing.firstWhere((b) => b.filePath == task.filePath);
      }

      // 创建书籍记录
      final companion = Book(
        id: 0, // 0 表示新书籍，数据库会生成 ID
        title: task.title ?? task.fileName,
        author: task.author ?? '未知作者',
        filePath: task.filePath,
        fileType: task.format,
        fileSize: task.fileSize,
        totalChapters: task.chapterCount ?? 0,
        totalCharacters: task.chapterCount ?? 0,
        coverPath: task.coverPath,
        description: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _repository.addBook(companion);
      final newBook = await _repository.getBookById(id);

      if (newBook != null) {
        _state.addBook(newBook);

        // 保存章节信息到数据库
        await _saveChapters(newBook.id, task);
      }

      return newBook;
    } catch (e) {
      Logging.debug('BookshelfService.addBookFromImportTask error: $e');
      return null;
    }
  }

  /// 保存章节信息到数据库
  Future<void> _saveChapters(int bookId, ImportTask task) async {
    if (task.chapterCount == 0 || task.chapters.isEmpty) {
      return;
    }

    try {
      final chapters = task.chapters.map((chapter) {
        return DbChaptersCompanion.insert(
          bookId: bookId,
          title: chapter.title,
          contentFile: task.filePath, // 章节内容存储在原文件
          chapterIndex: chapter.index,
          wordCount: const Value.absent(),
        );
      }).toList();

      // 使用 Chapter Repository 层方法批量插入
      await _chapter.insertChapters(chapters);

      // 更新书籍的总章节数
      final book = await _repository.getBookById(bookId);
      if (book != null) {
        await _repository.updateBook(
          book.copyWith(totalChapters: task.chapterCount ?? 0),
        );
      }
    } catch (e) {
      Logging.debug('BookshelfService._saveChapters error: $e');
    }
  }

  /// 添加书籍到书架（通用方法）
  Future<Book?> addBook({
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
      // 检查是否已存在
      final existing = await _repository.getAllBooks();
      final exists = existing.any((b) => b.filePath == filePath);

      if (exists) {
        Logging.debug('书籍已存在：$filePath');
        return existing.firstWhere((b) => b.filePath == filePath);
      }

      final companion = Book(
        id: 0, // 0 表示新书籍，数据库会生成 ID
        title: title,
        author: author,
        filePath: filePath,
        fileType: fileFormat,
        fileSize: fileSize,
        totalChapters: totalChapters,
        totalCharacters: totalCharacters,
        coverPath: coverPath,
        description: description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _repository.addBook(companion);
      final newBook = await _repository.getBookById(id);

      if (newBook != null) {
        _state.addBook(newBook);
      }

      return newBook;
    } catch (e) {
      Logging.debug('BookshelfService.addBook error: $e');
      return null;
    }
  }

  /// 删除书籍
  Future<bool> deleteBook(int bookId) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      // 删除关联数据（通过 Repository 层）
      await _repository.deleteBook(bookId);
      await _chapter.deleteChaptersByBookId(bookId);
      await _bookmark.deleteBookmarksByBookId(bookId);

      // 删除封面文件
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

  /// 批量删除书籍
  Future<int> deleteBooks(List<int> bookIds) async {
    int deletedCount = 0;

    for (final bookId in bookIds) {
      if (await deleteBook(bookId)) {
        deletedCount++;
      }
    }

    return deletedCount;
  }

  /// 更新书籍标题
  Future<bool> updateBookTitle(int bookId, String newTitle) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      await _repository.updateBook(book.copyWith(title: newTitle));

      // 更新状态
      final books = _state.books.value;
      final index = books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final updatedBook = books[index].copyWith(title: newTitle);
        _state.updateBook(updatedBook);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateBookTitle error: $e');
      return false;
    }
  }

  /// 更新书籍阅读状态
  Future<bool> updateBookStatus(int bookId, String status) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      await _repository.updateBook(book.copyWith(status: status));

      // 更新状态
      final books = _state.books.value;
      final index = books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final updatedBook = books[index].copyWith(status: status);
        _state.updateBook(updatedBook);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateBookStatus error: $e');
      return false;
    }
  }

  /// 更新书籍阅读进度
  Future<bool> updateReadingProgress({
    required int bookId,
    required int chapterId,
    required int currentPage,
    required int totalPages,
    required double progress,
  }) async {
    try {
      final book = await _repository.getBookById(bookId);
      if (book == null) return false;

      await _repository.updateBook(
        book.copyWith(
          currentChapterId: chapterId,
          currentPageIndex: currentPage,
          totalPages: totalPages,
          progress: progress,
          lastReadAt: DateTime.now(),
        ),
      );

      // 更新状态
      final books = _state.books.value;
      final index = books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final updatedBook = books[index].copyWith(
          currentChapterId: chapterId,
          currentPageIndex: currentPage,
          totalPages: totalPages,
          progress: progress,
          lastReadAt: DateTime.now(),
        );
        _state.updateBook(updatedBook);
      }

      return true;
    } catch (e) {
      Logging.debug('BookshelfService.updateReadingProgress error: $e');
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(int bookId) async {
    return await _repository.getBookById(bookId);
  }

  /// 获取书籍章节列表
  Future<List<Chapter>> getBookChapters(int bookId) async {
    return await _chapter.getChaptersByBookId(bookId);
  }

  /// 刷新书架
  Future<void> refresh() async {
    await loadBooks();
  }
}
