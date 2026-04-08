import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../domain/repositories/book_repository.dart';

/// 书架视图模型
@injectable
class BookshelfViewModel {
  final BookRepository _repo;

  /// 所有书籍
  final books = asyncSignal<List<DbBookRecord>>(AsyncState.loading());

  /// 所有分类（立即从缓存获取）
  final categories = signal<List<DbBookCategory>>([]);

  /// 当前选中的分类
  final selectedCategory = signal<DbBookCategory?>(null);

  /// 搜索关键词
  final searchKeyword = signal<String>('');

  /// 是否在搜索模式
  final isSearching = signal<bool>(false);

  BookshelfViewModel(this._repo) {
    _loadCategories();
    effect(() {
      loadBooks();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _repo.getAllCategories();
      categories.value = data;
      if (selectedCategory.value == null && data.isNotEmpty) {
        selectedCategory.value = data.first;
      }
    } catch (e) {
      categories.value = [];
    }
  }

  /// 加载书籍
  Future<void> loadBooks() async {
    books.value = AsyncState.loading();
    try {
      List<DbBookRecord> data;

      if (isSearching.value && searchKeyword.value.isNotEmpty) {
        data = await _repo.searchBooks(searchKeyword.value);
      } else {
        data = await _repo.getAllBooks();
      }

      books.value = AsyncState.data(data);
    } catch (e) {
      books.value = AsyncState.error(e);
    }
  }

  /// 切换分类
  void selectCategory(DbBookCategory category) {
    selectedCategory.value = category;
    isSearching.value = false;
    searchKeyword.value = '';
  }

  /// 开始搜索
  void startSearch() {
    isSearching.value = true;
  }

  /// 停止搜索
  void stopSearch() {
    isSearching.value = false;
    searchKeyword.value = '';
  }

  /// 更新搜索关键词
  void updateSearchKeyword(String keyword) {
    searchKeyword.value = keyword;
  }

  /// 删除书籍
  Future<bool> deleteBook(String id) async {
    try {
      await _repo.deleteBook(id);
      await loadBooks();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取书籍详情
  Future<DbBookRecord?> getBookDetail(String id) async {
    return await _repo.getBookById(id);
  }

  // ==================== 分类管理 ====================

  /// 添加分类
  Future<bool> addCategory({
    required String name,
    String color = '#FF5722',
    int sortOrder = 0,
  }) async {
    try {
      final category = DbBookCategory(
        id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        color: color,
        sortOrder: sortOrder,
        isSystem: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _repo.addCategory(category);
      await _loadCategories();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 更新分类
  Future<bool> updateCategory(DbBookCategory category) async {
    try {
      await _repo.updateCategory(category);
      await _loadCategories();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除分类
  Future<bool> removeCategory(String id) async {
    try {
      final category = await _repo.getCategoryById(id);
      if (category == null || category.isSystem) {
        return false;
      }
      await _repo.deleteCategory(id);
      await _loadCategories();
      if (selectedCategory.value?.id == id) {
        selectedCategory.value = categories.value.isEmpty
            ? null
            : categories.value.first;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 更新书籍分类
  Future<bool> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {
    try {
      await _repo.updateBookCategories(bookId, categoryIds);
      return true;
    } catch (e) {
      return false;
    }
  }
}
