import 'dart:convert';

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
    // 如果是第一个分类（全部），返回所有书籍
    if (category.sortOrder == 0) {
      return await getAllBooks();
    }
    // 根据分类 ID 筛选书籍
    final books = await _database.getAllBooks();
    return books
        .where((book) {
          final categoryIds = _parseCategoryIds(book.categoryIds);
          return categoryIds.contains(category.id);
        })
        .map(Book.fromDb)
        .toList();
  }

  /// 解析分类 ID 列表
  List<int> _parseCategoryIds(String categoryIdsJson) {
    try {
      if (categoryIdsJson.isEmpty || categoryIdsJson == '[]') {
        return [];
      }
      final decoded = jsonDecode(categoryIdsJson) as List;
      return decoded.cast<int>();
    } catch (e) {
      return [];
    }
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

  // ==================== 分类管理 ====================

  @override
  Future<List<BookCategory>> getAllCategories() async {
    final categories = await _database.getAllCategories();
    return categories.map(BookCategory.fromDb).toList();
  }

  @override
  Future<BookCategory?> getCategoryById(int id) async {
    final category = await _database.getCategoryById(id);
    return category != null ? BookCategory.fromDb(category) : null;
  }

  @override
  Future<int> addCategory(BookCategory category) async {
    return await _database.addCategory(
      DbBookCategoriesCompanion.insert(
        name: category.name,
        color: Value(category.color),
        sortOrder: Value(category.sortOrder),
        isSystem: Value(category.isSystem),
      ),
    );
  }

  @override
  Future<bool> updateCategory(BookCategory category) async {
    return await _database.updateCategory(
      DbBookCategoriesCompanion(
        id: Value(category.id),
        name: Value(category.name),
        color: Value(category.color),
        sortOrder: Value(category.sortOrder),
        isSystem: Value(category.isSystem),
        createdAt: Value(category.createdAt ?? DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<bool> deleteCategory(int id) async {
    return await _database.deleteCategory(id);
  }

  @override
  Future<bool> updateBookCategories(int bookId, List<int> categoryIds) async {
    // 将分类 ID 列表转换为 JSON 字符串存储
    final categoryIdsJson = jsonEncode(categoryIds);
    return await (_database.update(
          _database.dbBooks,
        )..where((tbl) => tbl.id.equals(bookId))).write(
          DbBooksCompanion(
            categoryIds: Value(categoryIdsJson),
            updatedAt: Value(DateTime.now()),
          ),
        ) >
        0;
  }
}
