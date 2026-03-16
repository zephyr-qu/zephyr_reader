/// 书架业务服务
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/database/database.dart';
import '../states/bookshelf_state.dart';
import 'book_import_service.dart';

/// 书架服务�?
class BookshelfService {
  final AppDatabase _db;
  final BookshelfState _state;

  BookshelfService(this._db, this._state);

  /// 加载书架书籍列表
  Future<void> loadBooks() async {
    _state.isLoading.value = true;
    _state.error.value = null;

    try {
      final books = await _db.getAllBooks();

      // 在内存中排序和筛�?
      var filteredBooks = books;
      final filter = _state.filter.value;

      // 筛�?
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
            .where((b) => b.fileFormat == filter.format)
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
      _state.error.value = '加载书架失败�?e';
      debugPrint('BookshelfService.loadBooks error: $e');
    } finally {
      _state.isLoading.value = false;
    }
  }

  /// 添加书籍到书架（集成 Rust 解析�?
  Future<Book?> addBookFromImportTask(ImportTask task) async {
    if (task.status != ImportTaskStatus.completed) {
      debugPrint('任务未完成，无法添加书籍');
      return null;
    }

    try {
      // 检查是否已存在（通过文件路径�?
      final existing = await _db.getAllBooks();
      final exists = existing.any((b) => b.filePath == task.filePath);

      if (exists) {
        debugPrint('书籍已存在：${task.filePath}');
        return existing.firstWhere((b) => b.filePath == task.filePath);
      }

      // 创建书籍记录
      final companion = BooksCompanion.insert(
        title: task.title ?? task.fileName,
        author: task.author ?? '未知作�?',
        filePath: task.filePath,
        fileFormat: task.format,
        fileSize: task.fileSize,
        totalChapters: task.chapterCount ?? 0,
        totalCharacters: task.chapterCount != null ? Value(task.chapterCount) : const Value(null),
        coverPath: task.coverPath != null ? Value(task.coverPath) : const Value(null),
        description: const Value(null),
      );

      final id = await _db.into(_db.Books).insert(companion);
      final newBook = await _db.getBookById(id);

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
      await _db.transaction(() async {
        for (final chapter in task.chapters) {
          await _db.into(_db.chapters).insert(
            ChaptersCompanion.insert(
              bookId: bookId,
              title: chapter.title,
              contentFile: task.filePath, // 章节内容存储在原文件�?
              chapterIndex: chapter.index,
              wordCount: Value(chapter.contentLength.toInt()),
            ),
          );
        }
      });

      // 更新书籍的总章节数
      await (await _db.update(_db.Books)..where((tbl) => tbl.id.equals(bookId)))
        .write(BooksCompanion(totalChapters: Value(task.chapterCount)));
    } catch (e) {
      debugPrint('BookshelfService._saveChapters error: $e');
    }
  }

  /// 添加书籍到书架（通用方法�?
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
      final existing = await _db.getAllBooks();
      final exists = existing.any((b) => b.filePath == filePath);

      if (exists) {
        debugPrint('书籍已存在：$filePath');
        return existing.firstWhere((b) => b.filePath == filePath);
      }

      final companion = BooksCompanion.insert(
        title: title,
        author: author,
        filePath: filePath,
        fileFormat: fileFormat,
        fileSize: fileSize,
        totalChapters: totalChapters,
        totalCharacters: totalCharacters > 0 ? Value(totalCharacters) : const Value(null),
        coverPath: coverPath != null ? Value(coverPath) : const Value(null),
        description: description != null ? Value(description!) : const Value(null),
      );

      final id = await _db.into(_db.Books).insert(companion);
      final newBook = await _db.getBookById(id);

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
      final book = await _db.getBookById(bookId);
      if (book == null) return false;

      // 删除关联数据
      await (await _db.delete(_db.Books)..where((tbl) => tbl.id.equals(bookId))).go();
      await (await _db.delete(_db.chapters)..where((tbl) => tbl.bookId.equals(bookId))).go();
      await (await _db.delete(_db.bookmarks)..where((tbl) => tbl.bookId.equals(bookId))).go();

      // 删除封面文件
      if (book.coverPath != null) {
        try {
          final coverFile = File(book.coverPath!);
          if (await coverFile.exists()) {
            await coverFile.delete();
          }
        } catch (e) {
          debugPrint('删除封面文件失败�?e');
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

  /// 更新书籍阅读状�?
  Future<bool> updateBookStatus(int bookId, String status) async {
    try {
      await _db.update(_db.Books).write(
        BooksCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
        where: (tbl) => tbl.id.equals(bookId),
      );

      // 更新状�?
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
      await (await _db.update(_db.Books)..where((tbl) => tbl.id.equals(bookId)))
        .write(BooksCompanion(
          currentChapterId: Value(chapterId),
          currentPageIndex: Value(currentPage),
          totalPages: Value(totalPages),
          progress: Value(progress),
          lastReadAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

      // 更新状�?
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
      debugPrint('BookshelfService.updateReadingProgress error: $e');
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(int bookId) async {
    return await _db.getBookById(bookId);
  }

  /// 获取书籍章节列表
  Future<List<Chapter>> getBookChapters(int bookId) async {
    return await _db.getChaptersByNovelId(bookId);
  }

  /// 刷新书架
  Future<void> refresh() async {
    await loadBooks();
  }
}
