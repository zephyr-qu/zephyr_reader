import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../data/repositories/rust_book_repository.dart';

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
  final BookRepository _repo;
  final SharedPreferences _prefs;

  /// 所有书籍
  final books = asyncSignal<List<Book>>(AsyncState.loading());

  /// 所有分类（立即从缓存获取）
  final categories = signal<List<BookCategory>>([]);

  /// 当前选中的分类
  final selectedCategory = signal<BookCategory?>(null);

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

  void Function()? _disposeEffect;

  BookshelfViewModel(this._repo, this._prefs) {
    _loadSettings();
    _loadCategories();
    _disposeEffect = effect(() {
      loadBooks();
    });
  }

  void dispose() {
    _disposeEffect?.call();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _repo.getAllCategories();
      categories.value = data;
    } catch (e, stack) {
      debugPrint('BookshelfViewModel._loadCategories error: $e\n$stack');
      categories.value = [];
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
        final cat = selectedCategory.value;
        final status = selectedStatus.value;
        if (cat != null && status != null) {
          data = await _repo.getBooksByCategory(cat);
          data = data.where((b) => b.status == status).toList();
        } else if (cat != null) {
          data = await _repo.getBooksByCategory(cat);
        } else if (status != null) {
          data = await _repo.getBooksByStatus(status);
        } else {
          data = await _repo.getAllBooks();
        }
      }

      data = List.from(data);
      data.sort((a, b) {
        switch (defaultSortType.value) {
          case BookshelfSortType.title:
            return a.title.compareTo(b.title);
          case BookshelfSortType.author:
            return (a.author ?? '').compareTo(b.author ?? '');
          case BookshelfSortType.lastRead:
            return -(a.lastOpenedAt ?? DateTime(2000)).compareTo(b.lastOpenedAt ?? DateTime(2000));
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

  Future<Set<String>> getBookCategoryIds(String bookId) async {
    try {
      return await _repo.getBookCategoryIds(bookId);
    } catch (_) {
      return {};
    }
  }

  /// 切换分类
  void selectCategory(BookCategory? category) {
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
      await _repo.deleteBook(id);
      await loadBooks();
      return true;
    } catch (e, stack) {
      debugPrint('BookshelfViewModel.deleteBook error: $e\n$stack');
      return false;
    }
  }

  /// 获取书籍详情
  Future<Book?> getBookDetail(String id) async {
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
    } catch (e, stack) {
      debugPrint('BookshelfViewModel.addCategory error: $e\n$stack');
      return false;
    }
  }

  /// 更新分类
  Future<bool> updateCategory(BookCategory category) async {
    try {
      await _repo.updateCategory(category);
      await _loadCategories();
      return true;
    } catch (e, stack) {
      debugPrint('BookshelfViewModel.updateCategory error: $e\n$stack');
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
    } catch (e, stack) {
      debugPrint('BookshelfViewModel.removeCategory error: $e\n$stack');
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
    } catch (e, stack) {
      debugPrint('BookshelfViewModel.updateBookCategories error: $e\n$stack');
      return false;
    }
  }

  static const String _keyShowReadingProgress = 'bookshelf.show_reading_progress';
  static const String _keyShowRecentReading = 'bookshelf.show_recent_reading';
  static const String _keyDefaultSortType = 'bookshelf.default_sort_type';

  void _loadSettings() {
    showReadingProgress.value = _prefs.getBool(_keyShowReadingProgress) ?? true;
    showRecentReading.value = _prefs.getBool(_keyShowRecentReading) ?? true;
    defaultSortType.value = BookshelfSortType.fromKey(
      _prefs.getString(_keyDefaultSortType) ?? 'last_read',
    );
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

  Future<BookshelfSortType?> showSortTypeDialog(BuildContext context) async {
    return showDialog<BookshelfSortType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择排序方式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BookshelfSortType.values.map((type) {
            return ListTile(
              title: Text(type.displayName),
              trailing: defaultSortType.value == type
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(context, type),
            );
          }).toList(),
        ),
      ),
    );
  }
}
