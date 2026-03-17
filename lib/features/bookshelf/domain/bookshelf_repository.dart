import 'package:zephyr_reader/domain/models/book.dart';

import 'models/book_category.dart';

/// 书架仓库接口
abstract class BookshelfRepository {
  /// 获取所有书籍
  Future<List<Book>> getAllBooks();

  /// 根据分类获取书籍
  Future<List<Book>> getBooksByCategory(BookCategory category);

  /// 根据ID获取书籍
  Future<Book?> getBookById(int id);

  /// 添加书籍
  Future<int> addBook(Book book);

  /// 更新书籍
  Future<bool> updateBook(Book book);

  /// 删除书籍
  Future<bool> deleteBook(int id);

  /// 搜索书籍
  Future<List<Book>> searchBooks(String keyword);
}
