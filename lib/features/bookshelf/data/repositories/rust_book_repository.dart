/// 基于 Rust 存储的书籍仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';

import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: BookRepository)
class RustBookRepository implements BookRepository {
  final _storage = RustStorageService();

  @override
  Future<List<DbBookRecord>> getAllBooks() async {
    return _storage.getAllBooks();
  }

  @override
  Future<List<DbBookRecord>> getBooksByCategory(
    DbBookCategory category,
  ) async {
    final allBooks = await getAllBooks();
    final booksWithCategory = <DbBookRecord>[];
    for (final book in allBooks) {
      final categories = _storage.getCategoriesForBook(book.bookId);
      if (categories.any((c) => c.id == category.id)) {
        booksWithCategory.add(book);
      }
    }
    return booksWithCategory;
  }

  @override
  Future<DbBookRecord?> getBookById(String id) async {
    final allBooks = await getAllBooks();
    return allBooks.where((b) => b.bookId == id).firstOrNull;
  }

  @override
  Future<void> addBook(DbBookRecord book) async {
    _storage.saveBook(book);
  }

  @override
  Future<void> updateBook(DbBookRecord book) async {
    _storage.saveBook(book);
  }

  @override
  Future<void> deleteBook(String id) async {
    _storage.deleteBook(id);
  }

  @override
  Future<List<DbBookRecord>> searchBooks(String keyword) async {
    return _storage.searchBooks(keyword);
  }

  @override
  Future<List<DbBookRecord>> getBooksByStatus(DbBookStatus status) async {
    final all = _storage.getAllBooks();
    return all.where((b) => b.status == status).toList();
  }

  @override
  Future<List<DbBookCategory>> getAllCategories() async {
    return _storage.getAllCategories();
  }

  @override
  Future<DbBookCategory?> getCategoryById(String id) async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> addCategory(DbBookCategory category) async {
    _storage.saveCategory(category);
  }

  @override
  Future<void> updateCategory(DbBookCategory category) async {
    _storage.saveCategory(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    _storage.deleteCategory(id);
  }

  @override
  Future<void> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {
    await _storage.setCategoriesForBook(bookId, categoryIds);
  }
}
