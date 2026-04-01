import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/application/services/category_cache_service.dart';

import '../domain/repositories/book_repository.dart';
import '../domain/models/book_category.dart';

/// 书架视图模型
@injectable
class BookshelfViewModel {
  final BookRepository _repo;
  final CategoryCacheService _cacheService;

  /// 所有书籍
  final books = asyncSignal<List<Book>>(AsyncState.loading());

  /// 所有分类（立即从缓存获取）
  final categories = signal<List<BookCategory>>([]);

  /// 当前选中的分类
  final selectedCategory = signal<BookCategory?>(null);

  /// 搜索关键词
  final searchKeyword = signal<String>('');

  /// 是否在搜索模式
  final isSearching = signal<bool>(false);

  BookshelfViewModel(this._repo, this._cacheService) {
    // 立即从缓存加载分类（无延迟）
    _loadCategoriesFromCache();
    // 后台异步刷新分类
    _refreshCategories();
    effect(() {
      loadBooks();
    });
  }

  /// 从缓存加载分类（立即显示）
  void _loadCategoriesFromCache() {
    final cachedCategories = _cacheService.categories;
    categories.value = cachedCategories;
    if (cachedCategories.isNotEmpty && selectedCategory.value == null) {
      selectedCategory.value = cachedCategories.first;
    }
  }

  /// 后台刷新分类
  Future<void> _refreshCategories() async {
    try {
      final data = await _repo.getAllCategories();
      _cacheService.updateCategories(data);
      categories.value = data;
      // 确保选中第一个分类
      if (selectedCategory.value == null && data.isNotEmpty) {
        selectedCategory.value = data.first;
      }
    } catch (e) {
      // 如果刷新失败，使用缓存（已经有默认值）
      categories.value = _cacheService.categories;
    }
  }

  /// 加载书籍
  Future<void> loadBooks() async {
    books.value = AsyncState.loading();
    try {
      List<Book> data;

      if (isSearching.value && searchKeyword.value.isNotEmpty) {
        data = await _repo.searchBooks(searchKeyword.value);
      } else {
        final category = selectedCategory.value;
        if (category != null) {
          data = await _repo.getBooksByCategory(category);
        } else {
          data = [];
        }
      }

      books.value = AsyncState.data(data);
    } catch (e) {
      books.value = AsyncState.error(e);
    }
  }

  /// 切换分类
  void selectCategory(BookCategory category) {
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
  Future<bool> deleteBook(int id) async {
    try {
      final success = await _repo.deleteBook(id);
      if (success) {
        await loadBooks();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(int id) async {
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
      final category = BookCategory(
        id: 0,
        name: name,
        color: color,
        sortOrder: sortOrder,
        isSystem: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final id = await _repo.addCategory(category);
      if (id > 0) {
        // 更新缓存
        final newCategory = category.copyWith(id: id);
        _cacheService.addCategory(newCategory);
        categories.value = List.from(_cacheService.categories);
      }
      return id > 0;
    } catch (e) {
      return false;
    }
  }

  /// 更新分类
  Future<bool> updateCategory(BookCategory category) async {
    try {
      final success = await _repo.updateCategory(category);
      if (success) {
        // 更新缓存
        _cacheService.updateCategoryInCache(category);
        categories.value = List.from(_cacheService.categories);
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 删除分类
  Future<bool> removeCategory(int id) async {
    try {
      final category = await _repo.getCategoryById(id);
      if (category == null || category.isSystem) {
        return false;
      }
      final success = await _repo.deleteCategory(id);
      if (success) {
        // 更新缓存
        _cacheService.removeCategory(id);
        categories.value = List.from(_cacheService.categories);
        // 如果当前选中的是被删除的分类，切换到第一个
        if (selectedCategory.value?.id == id) {
          selectedCategory.value = categories.value.first;
        }
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 更新书籍分类
  Future<bool> updateBookCategories(int bookId, List<int> categoryIds) async {
    try {
      return await _repo.updateBookCategories(bookId, categoryIds);
    } catch (e) {
      return false;
    }
  }
}
