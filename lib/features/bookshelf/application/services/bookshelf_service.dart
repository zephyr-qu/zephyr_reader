/// 书架业务服务
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/domain/models/chapter.dart';

import '../../../../core/database/database.dart';
import '../../data/bookshelf_local_data_source.dart';
import '../states/bookshelf_state.dart';
import 'book_import_service.dart';

/// 书架业务服务
///
/// 负责书架相关的业务逻辑，包括：
/// - 书籍列表加载、筛选、排序
/// - 书籍导入与解析
/// - 书籍删除与文件清理
/// - 阅读进度更新
class BookshelfService {
  final BookshelfLocalDataSource _dataSource;
  final BookshelfState _state;

  BookshelfService(this._dataSource, this._state);

  /// 加载书架书籍列表
  Future<void> loadBooks() async {
    _state.isLoading.value = true;
    _state.error.value = null;

    try {
      final books = await _dataSource.getAllBooks();

      // 在内存中排序和筛
      var filteredBooks = books;
      final filter = _state.filter.value;

      // 筛
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
                : b.author.compareTo(a.author);
          case BookshelfSortType.progress:
            return filter.ascending
                ? a.progress.compareTo(b.progress)
                : b.progress.compareTo(a.progress);
        }
      });

      _state.setBooks(filteredBooks);
    } catch (e) {
      _state.error.value = '加载书架失败e';
      debugPrint('BookshelfService.loadBooks error: $e');
    } finally {
      _state.isLoading.value = false;
    }
  }

  /// 添加书籍到书架
  Future<Book?> addBookFromImportTask(ImportTask task) async {
    if (task.status != ImportTaskStatus.completed) {
      debugPrint('任务未完成，无法添加书籍');
      return null;
    }

    try {
      // 检查是否已存在（通过文件路径
      final existing = await _dataSource.getAllBooks();
      final exists = existing.any((b) => b.filePath == task.filePath);

      if (exists) {
        debugPrint('书籍已存在：${task.filePath}');
        return existing.firstWhere((b) => b.filePath == task.filePath);
      }

      // 创建书籍记录
      final companion = DbBooksCompanion.insert(
        title: task.title ?? task.fileName,
        author: task.author ?? '未知作',
        filePath: task.filePath,
        fileType: task.format,
        fileSize: Value(task.fileSize),
        totalChapters: Value(task.chapterCount ?? 0),
        totalCharacters: task.chapterCount != null
            ? Value(task.chapterCount!)
            : Value(0),
        coverPath: task.coverPath != null
            ? Value(task.coverPath)
            : const Value(null),
        description: const Value(null),
        id: Value(task.bookId),
      );

      final id = await _dataSource.addBook(companion as Book);
      final newBook = await _dataSource.getBookById(id);

      if (newBook != null) {
        _state.addBook(newBook);

        // 保存章节信息到数据库
        await _saveChapters(newBook.id, task);
      }

      return newBook;
    } catch (e) {
      debugPrint('BookshelfService.addBookFromImportTask error: $e');
      return null;
    }
  }

  /// 保存章节信息到数据库
  Future<void> _saveChapters(int bookId, ImportTask task) async {
    if (task.chapterCount == 0 || task.chapters.isEmpty) {
      return;
    }

    try {
      // 使用事务批量插入
      await _dataSource.database.transaction(() async {
        for (final chapter in task.chapters) {
          await _dataSource.database
              .into(_dataSource.database.dbChapters)
              .insert(
                DbChaptersCompanion.insert(
                  bookId: bookId,
                  title: chapter.title,
                  contentFile: task.filePath, // 章节内容存储在原文件
                  chapterIndex: chapter.index,
                  wordCount: Value(chapter.contentLength.toInt()),

                ),
              );
        }
      });

      // 更新书籍的总章节数
      await (_dataSource.database.update(_dataSource.database.dbBooks)
            ..where((tbl) => tbl.id.equals(bookId)))
          .write(
            DbBooksCompanion(totalChapters: Value(task.chapterCount ?? 0)),
          );
    } catch (e) {
      debugPrint('BookshelfService._saveChapters error: $e');
    }
  }

  /// 添加书籍到书架（通用方法
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
      final existing = await _dataSource.getAllBooks();
      final exists = existing.any((b) => b.filePath == filePath);

      if (exists) {
        debugPrint('书籍已存在：$filePath');
        return existing.firstWhere((b) => b.filePath == filePath);
      }

      final companion = DbBooksCompanion.insert(
        title: title,
        author: author,
        filePath: filePath,
        fileType: fileFormat,
        fileSize: Value(fileSize),
        totalChapters: Value(totalChapters),
        totalCharacters: totalCharacters > 0
            ? Value(totalCharacters)
            : Value(0),
        coverPath: coverPath != null ? Value(coverPath) : const Value(null),
        description: description != null
            ? Value(description)
            : const Value(null),

      );

      final id = await _dataSource.addBook(companion as Book);
      final newBook = await _dataSource.getBookById(id);

      if (newBook != null) {
        _state.addBook(newBook);
      }

      return newBook;
    } catch (e) {
      debugPrint('BookshelfService.addBook error: $e');
      return null;
    }
  }

  /// 删除书籍
  Future<bool> deleteBook(int bookId) async {
    try {
      final book = await _dataSource.getBookById(bookId);
      if (book == null) return false;

      // 删除关联数据
      await _dataSource.deleteBook(bookId);
      await (_dataSource.database.delete(
        _dataSource.database.dbChapters,
      )..where((tbl) => tbl.bookId.equals(bookId))).go();
      await (_dataSource.database.delete(
        _dataSource.database.dbBookmarks,
      )..where((tbl) => tbl.bookId.equals(bookId))).go();

      // 删除封面文件
      if (book.coverPath != null) {
        try {
          final coverFile = File(book.coverPath!);
          if (await coverFile.exists()) {
            await coverFile.delete();
          }
        } catch (e) {
          debugPrint('删除封面文件失败e');
        }
      }

      _state.removeBook(bookId);
      return true;
    } catch (e) {
      debugPrint('BookshelfService.deleteBook error: $e');
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

  /// 更新书籍阅读状
  Future<bool> updateBookStatus(int bookId, String status) async {
    try {
      await (_dataSource.database.update(
        _dataSource.database.dbBooks,
      )..where((tbl) => tbl.id.equals(bookId))).write(
        DbBooksCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 更新状
      final books = _state.books.value;
      final index = books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final updatedBook = books[index].copyWith(status: status);
        _state.updateBook(updatedBook);
      }

      return true;
    } catch (e) {
      debugPrint('BookshelfService.updateBookStatus error: $e');
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
      await (_dataSource.database.update(
        _dataSource.database.dbBooks,
      )..where((tbl) => tbl.id.equals(bookId))).write(
        DbBooksCompanion(
          currentChapterId: Value(chapterId),
          currentPageIndex: Value(currentPage),
          totalPages: Value(totalPages),
          progress: Value(progress),
          lastReadAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // 更新状
      final books = _state.books.value;
      final index = books.indexWhere((b) => b.id == bookId);
      if (index != -1) {
        final updatedBook = books[index].copyWith(
          currentChapterId: Value(chapterId),
          currentPageIndex: currentPage,
          totalPages: totalPages,
          progress: progress,
          lastReadAt: Value(DateTime.now()),
        );
        _state.updateBook(updatedBook);
      }

      return true;
    } catch (e) {
      debugPrint('BookshelfService.updateReadingProgress error: $e');
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(int bookId) async {
    return await _dataSource.getBookById(bookId);
  }

  /// 获取书籍章节列表
  Future<List<Chapter>> getBookChapters(int bookId) async {
    final chapters = await _dataSource.database.getChaptersByBookId(bookId);
    return chapters.map((c) => Chapter.fromDb(c)).toList();
  }

  /// 刷新书架
  Future<void> refresh() async {
    await loadBooks();
  }
}
