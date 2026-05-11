/// 基于 Rust 存储的书籍仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';

import 'package:zephyr_reader/features/bookshelf/domain/repositories/book_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: BookRepository)
class RustBookRepository implements BookRepository {
  final RustStorageService _storage;
  RustBookRepository(this._storage);

  @override
  Future<List<Book>> getAllBooks() async {
    return _storage.getAllBooks();
  }

  @override
  Future<List<Book>> getBooksByCategory(
    BookCategory category,
  ) async {
    final allBooks = await getAllBooks();
    final booksWithCategory = <Book>[];
    for (final book in allBooks) {
      final categories = await _storage.getCategoriesForBook(book.bookId);
      if (categories.any((c) => c.id == category.id)) {
        booksWithCategory.add(book);
      }
    }
    return booksWithCategory;
  }

  @override
  Future<Book?> getBookById(String id) async {
    final allBooks = await getAllBooks();
    return allBooks.where((b) => b.bookId == id).firstOrNull;
  }

  @override
  Future<void> addBook(Book book) async {
    await _storage.saveBook(book);
  }

  @override
  Future<void> updateBook(Book book) async {
    await _storage.saveBook(book);
  }

  @override
  Future<void> deleteBook(String id) async {
    await _storage.deleteBook(id);
  }

  @override
  Future<List<Book>> searchBooks(String keyword) async {
    return _storage.searchBooks(keyword);
  }

  @override
  Future<List<Book>> getBooksByStatus(BookStatus status) async {
    final all = await _storage.getAllBooks();
    return all.where((b) => b.status == status).toList();
  }

  @override
  Future<List<BookCategory>> getAllCategories() async {
    return _storage.getAllCategories();
  }

  @override
  Future<BookCategory?> getCategoryById(String id) async {
    final allCategories = await getAllCategories();
    return allCategories.where((c) => c.id == id).firstOrNull;
  }

  @override
  Future<void> addCategory(BookCategory category) async {
    await _storage.saveCategory(category);
  }

  @override
  Future<void> updateCategory(BookCategory category) async {
    await _storage.saveCategory(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _storage.deleteCategory(id);
  }

  @override
  Future<void> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {
    await _storage.setCategoriesForBook(bookId, categoryIds);
  }
}
