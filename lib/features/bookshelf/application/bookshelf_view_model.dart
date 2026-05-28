import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架排序方式
enum BookshelfSortType {
  lastRead('last_read', '最近阅读'),
  createdAt('created_at', '添加时间'),
  title('title', '书名'),
  author('author', '作者'),
  progress('progress', '阅读进度');

  final String key;
  final String displayName;
  const BookshelfSortType(this.key, this.displayName);

  static BookshelfSortType fromKey(String key) {
    return BookshelfSortType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => BookshelfSortType.lastRead,
    );
  }
}

@injectable
class BookshelfViewModel {
  final SharedPreferences _prefs;

  /// 所有书籍
  final books = asyncSignal<List<Book>>(AsyncState.loading());

  /// 所有分类（立即从缓存获取）
  final categories = signal<List<Category>>([]);

  /// 当前选中的分类
  final selectedCategory = signal<Category?>(null);

  /// 当前选中的阅读状态
  final selectedStatus = signal<BookStatus?>(null);

  /// 搜索关键词
  final searchKeyword = signal<String>('');

  /// 是否在搜索模式
  final isSearching = signal<bool>(false);

  /// 显示阅读进度
  final showReadingProgress = signal<bool>(true);

  /// 显示最近阅读
  final showRecentReading = signal<bool>(true);

  /// 默认排序方式
  final defaultSortType = signal<BookshelfSortType>(BookshelfSortType.lastRead);

  /// 阅读进度映射 (bookId -> progress 0.0~1.0)
  final readingProgress = signal<Map<String, double>>({});

  /// 最近阅读的书籍
  final recentBooks = signal<List<Book>>([]);

  /// 是否使用列表视图（false=网格视图）
  final isListView = signal<bool>(false);

  BookshelfViewModel(this._prefs) {
    _loadSettings();
    _loadCategories();
    loadBooks();
  }

  void dispose() {}

  Future<void> _loadCategories() async {
    try {
      final data = await category_api.listCategories();
      categories.value = data.cast<Category>();
    } catch (e, stack) {
      Logging.error('BookshelfViewModel._loadCategories error', exception: e, stackTrace: stack);
      categories.value = [];
    }
  }

  /// 加载书籍
  Future<void> loadBooks() async {
    books.value = AsyncState.loading();
    try {
      List<Book> data;

      if (isSearching.value && searchKeyword.value.isNotEmpty) {
        data = await book_api.searchBooks(keyword: searchKeyword.value);
      } else {
        data = await book_api.listBooks();
      }

      data = List.from(data);

      recentBooks.value = await book_api.listRecentlyOpenedBooks(
        limit: BigInt.from(10),
      );

      final allProgress = await progress_api.listAllProgresses();
      final progressMap = <String, double>{};
      for (final item in allProgress) {
        if (item.progress != null) {
          progressMap[item.book.bookId] = item.progress!.progress;
        }
      }
      readingProgress.value = progressMap;

      data.sort((a, b) {
        switch (defaultSortType.value) {
          case BookshelfSortType.title:
            return a.title.compareTo(b.title);
          case BookshelfSortType.author:
            return (a.author ?? '').compareTo(b.author ?? '');
          case BookshelfSortType.lastRead:
            return -(a.lastOpenedAt ?? DateTime(2000)).compareTo(
              b.lastOpenedAt ?? DateTime(2000),
            );
          case BookshelfSortType.progress:
          case BookshelfSortType.createdAt:
            return -(a.addedAt).compareTo(b.addedAt);
        }
      });

      books.value = AsyncState.data(data);
    } catch (e) {
      books.value = AsyncState.error(e);
    }
  }

  Future<Set<String>> getCategoryIds(String bookId) async {
    try {
      final cats = await category_api.listCategoriesByBook(bookId: bookId);
      return cats.map((c) => c.id).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 切换分类
  void selectCategory(Category? category) {
    selectedCategory.value = category;
    isSearching.value = false;
    searchKeyword.value = '';
  }

  /// 切换状态筛选
  void selectStatus(BookStatus? status) {
    selectedStatus.value = status;
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
      await book_api.deleteBook(bookId: id);
      await loadBooks();
      return true;
    } catch (e, stack) {
      Logging.error('BookshelfViewModel.deleteBook error', exception: e, stackTrace: stack);
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(String id) async {
    return await book_api.getBook(bookId: id);
  }

  // ==================== 分类管理 ====================

  /// 添加分类
  Future<bool> addCategory({
    required String name,
    String color = '#FF5722',
    int sortOrder = 0,
  }) async {
    try {
      await category_api.upsertCategory(
        name: name,
        color: color,
        sortOrder: sortOrder,
      );
      await _loadCategories();
      return true;
    } catch (e, stack) {
      Logging.error('BookshelfViewModel.addCategory error', exception: e, stackTrace: stack);
      return false;
    }
  }

  /// 更新分类
  Future<bool> updateCategory(Category category) async {
    try {
      await category_api.upsertCategory(
        name: category.name,
        color: category.color,
        sortOrder: category.sortOrder,
        description: category.description,
        categoryId: category.id,
      );
      await _loadCategories();
      return true;
    } catch (e, stack) {
      Logging.error('BookshelfViewModel.updateCategory error', exception: e, stackTrace: stack);
      return false;
    }
  }

  /// 删除分类
  Future<bool> removeCategory(String id) async {
    try {
      final category = await category_api.getCategory(categoryId: id);
      if (category == null) {
        return false;
      }
      await category_api.deleteCategory(categoryId: id);
      await _loadCategories();
      if (selectedCategory.value?.id == id) {
        selectedCategory.value = categories.value.isEmpty
            ? null
            : categories.value.first;
      }
      return true;
    } catch (e, stack) {
      Logging.error('BookshelfViewModel.removeCategory error', exception: e, stackTrace: stack);
      return false;
    }
  }

  /// 更新书籍分类
  Future<bool> updateBookCategories(
    String bookId,
    List<String> categoryIds,
  ) async {
    try {
      await category_api.setCategoriesForBook(
        bookId: bookId,
        categoryIds: categoryIds,
      );
      return true;
    } catch (e, stack) {
      Logging.error('BookshelfViewModel.updateBookCategories error', exception: e, stackTrace: stack);
      return false;
    }
  }

  static const String _keyShowReadingProgress =
      'bookshelf.show_reading_progress';
  static const String _keyShowRecentReading = 'bookshelf.show_recent_reading';
  static const String _keyDefaultSortType = 'bookshelf.default_sort_type';
  static const String _keyIsListView = 'bookshelf.is_list_view';

  void _loadSettings() {
    showReadingProgress.value = _prefs.getBool(_keyShowReadingProgress) ?? true;
    showRecentReading.value = _prefs.getBool(_keyShowRecentReading) ?? true;
    defaultSortType.value = BookshelfSortType.fromKey(
      _prefs.getString(_keyDefaultSortType) ?? 'last_read',
    );
    isListView.value = _prefs.getBool(_keyIsListView) ?? false;
  }

  Future<void> setShowReadingProgress(bool value) async {
    showReadingProgress.value = value;
    await _prefs.setBool(_keyShowReadingProgress, value);
  }

  Future<void> setShowRecentReading(bool value) async {
    showRecentReading.value = value;
    await _prefs.setBool(_keyShowRecentReading, value);
  }

  Future<void> setDefaultSortType(BookshelfSortType type) async {
    defaultSortType.value = type;
    await _prefs.setString(_keyDefaultSortType, type.key);
  }

  void toggleViewMode() {
    isListView.value = !isListView.value;
    _prefs.setBool(_keyIsListView, isListView.value);
  }
}
