import 'package:zephyr_reader/domain/models/book.dart';

import '../models/book_category.dart';

/// 书架仓库接口
abstract class BookRepository {
  /// 获取所有书籍
  Future<List<Book>> getAllBooks();

  /// 根据分类获取书籍
  Future<List<Book>> getBooksByCategory(BookCategory category);

  /// 根据 ID 获取书籍
  Future<Book?> getBookById(int id);

  /// 添加书籍
  Future<int> addBook(Book book);

  /// 更新书籍
  Future<bool> updateBook(Book book);

  /// 删除书籍
  Future<bool> deleteBook(int id);

  /// 搜索书籍
  Future<List<Book>> searchBooks(String keyword);

  // ==================== 分类管理 ====================

  /// 获取所有分类
  Future<List<BookCategory>> getAllCategories();

  /// 根据 ID 获取分类
  Future<BookCategory?> getCategoryById(int id);

  /// 添加分类
  Future<int> addCategory(BookCategory category);

  /// 更新分类
  Future<bool> updateCategory(BookCategory category);

  /// 删除分类
  Future<bool> deleteCategory(int id);

  /// 更新书籍分类
  Future<bool> updateBookCategories(int bookId, List<int> categoryIds);
}
