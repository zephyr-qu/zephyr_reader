import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/book.dart';

import '../../domain/models/book_category.dart';
import '../../domain/repositories/book_repository.dart';

/// 书架仓库实现
///
/// 负责直接与数据库交互，提供基础的 CRUD 操作
@LazySingleton(as: BookRepository)
class BookRepositoryImpl implements BookRepository {
  final AppDatabase _database;

  BookRepositoryImpl(this._database);

  @override
  Future<List<Book>> getAllBooks() async {
    final books = await _database.getAllBooks();
    return books.map(Book.fromDb).toList();
  }

  @override
  Future<List<Book>> getBooksByCategory(BookCategory category) async {
    if (category == BookCategory.all) {
      return await getAllBooks();
    }
    final books = await (_database.select(
      _database.dbBooks,
    )..where((tbl) => tbl.status.equals(category.name))).get();
    return books.map(Book.fromDb).toList();
  }

  @override
  Future<Book?> getBookById(int id) async {
    final book = await _database.getBookById(id);
    return book != null ? Book.fromDb(book) : null;
  }

  @override
  Future<int> addBook(Book book) async {
    return await _database
        .into(_database.dbBooks)
        .insert(
          DbBooksCompanion(
            title: Value(book.title),
            author: Value(book.author),
            coverPath: Value(book.coverPath),
            description: Value(book.description),
            filePath: Value(book.filePath),
            fileType: Value(book.fileType),
            fileSize: Value(book.fileSize),
            totalChapters: Value(book.totalChapters),
            totalCharacters: Value(book.totalCharacters),
            status: Value(book.status),
            updatedAt: Value(DateTime.now()),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  @override
  Future<bool> updateBook(Book book) async {
    return await (_database.update(
          _database.dbBooks,
        )..where((tbl) => tbl.id.equals(book.id))).write(
          DbBooksCompanion(
            title: Value(book.title),
            author: Value(book.author),
            coverPath: Value(book.coverPath),
            description: Value(book.description),
            filePath: Value(book.filePath),
            fileType: Value(book.fileType),
            fileSize: Value(book.fileSize),
            totalChapters: Value(book.totalChapters),
            totalCharacters: Value(book.totalCharacters),
            status: Value(book.status),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  @override
  Future<bool> deleteBook(int id) async {
    return await (_database.delete(
          _database.dbBooks,
        )..where((tbl) => tbl.id.equals(id))).go() >
        0;
  }

  @override
  Future<List<Book>> searchBooks(String keyword) async {
    final books = await _database.searchBooks(keyword);
    return books.map(Book.fromDb).toList();
  }
}
