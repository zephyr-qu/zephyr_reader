import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架仓库接口
abstract class BookRepository {
  /// 获取所有书籍
  Future<List<DbBookRecord>> getAllBooks();

  /// 根据分类获取书籍
  Future<List<DbBookRecord>> getBooksByCategory(
    DbBookCategory category,
  );

  /// 根据 ID 获取书籍
  Future<DbBookRecord?> getBookById(String id);

  /// 添加书籍
  Future<void> addBook(DbBookRecord book);

  /// 更新书籍
  Future<void> updateBook(DbBookRecord book);

  /// 删除书籍
  Future<void> deleteBook(String id);

  /// 搜索书籍
  Future<List<DbBookRecord>> searchBooks(String keyword);

  // ==================== 分类管理 ====================

  /// 获取所有分类
  Future<List<DbBookCategory>> getAllCategories();

  /// 根据 ID 获取分类
  Future<DbBookCategory?> getCategoryById(String id);

  /// 添加分类
  Future<void> addCategory(DbBookCategory category);

  /// 更新分类
  Future<void> updateCategory(DbBookCategory category);

  /// 删除分类
  Future<void> deleteCategory(String id);

  /// 更新书籍分类
  Future<void> updateBookCategories(String bookId, List<String> categoryIds);
}
