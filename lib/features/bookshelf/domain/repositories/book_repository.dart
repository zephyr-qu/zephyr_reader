import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架仓库接口
abstract class BookRepository {
  /// 获取所有书籍
  Future<List<Book>> getAllBooks();

  /// 根据分类获取书籍
  Future<List<Book>> getBooksByCategory(
    BookCategory category,
  );

  /// 根据 ID 获取书籍
  Future<Book?> getBookById(String id);

  /// 添加书籍
  Future<void> addBook(Book book);

  /// 更新书籍
  Future<void> updateBook(Book book);

  /// 删除书籍
  Future<void> deleteBook(String id);

  /// 搜索书籍
  Future<List<Book>> searchBooks(String keyword);

  /// 按状态获取书籍
  Future<List<Book>> getBooksByStatus(BookStatus status);

  // ==================== 分类管理 ====================

  /// 获取所有分类
  Future<List<BookCategory>> getAllCategories();

  /// 根据 ID 获取分类
  Future<BookCategory?> getCategoryById(String id);

  /// 添加分类
  Future<void> addCategory(BookCategory category);

  /// 更新分类
  Future<void> updateCategory(BookCategory category);

  /// 删除分类
  Future<void> deleteCategory(String id);

  /// 更新书籍分类
  Future<void> updateBookCategories(String bookId, List<String> categoryIds);
}
