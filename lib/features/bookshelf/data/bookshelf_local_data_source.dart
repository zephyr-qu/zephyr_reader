import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/database/tables/books.dart';

import '../domain/bookshelf_repository.dart';
import '../domain/models/book_category.dart';

/// 书架本地数据源
///
/// 负责直接与数据库交互，提供基础的 CRUD 操作
@LazySingleton(as: BookshelfRepository)
class BookshelfLocalDataSource implements BookshelfRepository {
  final AppDatabase _database;

  BookshelfLocalDataSource(this._database);

  /// 获取数据库实例（供外部使用）
  AppDatabase get database => _database;

  @override
  Future<List<Book>> getAllBooks() async {
    return await _database.getAllBooks();
  }

  @override
  Future<List<Book>> getBooksByCategory(BookCategory category) async {
    if (category == BookCategory.all) {
      return await getAllBooks();
    }
    return await (_database.select(
      _database.books,
    )..where((tbl) => tbl.status.equals(category.name))).get();
  }

  @override
  Future<Book?> getBookById(int id) async {
    return await _database.getBookById(id);
  }

  @override
  Future<int> addBook(BooksCompanion book) async {
    return await _database.into(_database.books).insert(book);
  }

  @override
  Future<bool> updateBook(Book book) async {
    return await (_database.update(
          _database.books,
        )..where((tbl) => tbl.id.equals(book.id))).write(
          BooksCompanion(
            title: Value(book.title),
            author: Value(book.author),
            coverPath: Value(book.coverPath),
            description: Value(book.description),
            totalChapters: Value(book.totalChapters),
            status: Value(book.status),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }

  @override
  Future<bool> deleteBook(int id) async {
    return await (_database.delete(
          _database.books,
        )..where((tbl) => tbl.id.equals(id))).go() >
        0;
  }

  @override
  Future<List<Book>> searchBooks(String keyword) async {
    return await _database.searchBooks(keyword);
  }
}
