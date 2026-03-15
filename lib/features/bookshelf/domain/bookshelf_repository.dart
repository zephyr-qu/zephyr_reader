import 'package:zephyr_reader/core/database/database.dart';
import 'models/book_category.dart';

/// 书架仓库接口
abstract class BookshelfRepository {
  /// 获取所有书籍
  Future<List<Novel>> getAllBooks();

  /// 根据分类获取书籍
  Future<List<Novel>> getBooksByCategory(BookCategory category);

  /// 根据ID获取书籍
  Future<Novel?> getBookById(int id);

  /// 添加书籍
  Future<int> addBook(NovelsCompanion book);

  /// 更新书籍
  Future<bool> updateBook(Novel book);

  /// 删除书籍
  Future<bool> deleteBook(int id);

  /// 搜索书籍
  Future<List<Novel>> searchBooks(String keyword);
}