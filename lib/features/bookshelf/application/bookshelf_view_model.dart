import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/bookshelf/model/bookshelf_sort_type.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@lazySingleton
class BookshelfViewModel {
  final PreferencesService _prefs;
  final CategoryViewModel _categoryVM;
  static int _instanceCounter = 0;
  final int _instanceId;

  /// 自增世代计数器
  int _reloadGeneration = 0;


  /// 所有书籍
  final books = asyncSignal<List<BookshelfBook>>(AsyncState.loading());
  CategoryViewModel get categoryVM => _categoryVM;

  /// 当前选中的阅读状态
  final selectedStatus = signal<BookStatus?>(null);

  /// 搜索关键词
  final searchKeyword = signal<String>('');


  late final showReadingProgress = persistedBool(
    _prefs,
    SettingsKeys.bookshelfShowProgress,
    true,
  );
  late final defaultSortType = persistedEnumCustom(
    _prefs,
    SettingsKeys.bookshelfDefaultSort,
    BookshelfSortType.lastRead,
    (s) => BookshelfSortType.fromKey(s),
    (v) => v.key,
  );
  late final _isListView = persistedBool(
    _prefs,
    SettingsKeys.bookshelfIsListView,
    false,
  );
  Signal<bool> get isListView => _isListView.signal;


  BookshelfViewModel(this._prefs, this._categoryVM)
    : _instanceId = ++_instanceCounter;
  @override
  String toString() => 'BookshelfVM#$_instanceId';


  /// 加载书籍列表 + 排序（最常用的刷新）
  Future<void> reloadBooks() async {
    final gen = ++_reloadGeneration;
    Logging.debug(
      '[$this] reloadBooks() gen=$gen category=${_categoryVM.selectedCategory.value?.id} status=${selectedStatus.value?.name}',
    );
    try {
      List<BookshelfBook> data;
      final category = _categoryVM.selectedCategory.value;
      final status = selectedStatus.value;
      if (category != null && status != null) {
        data = await category_api.listBookshelfBooksByCategoryAndStatus(
          categoryId: category.id,
          status: status,
        );
      } else if (category != null) {
        data = await category_api.listBookshelfBooksByCategory(
          categoryId: category.id,
        );
      } else if (status != null) {
        data = await book_api.listBookshelfBooksByStatus(status: status);
      } else {
        final sort = defaultSortType.value;
        data = await book_api.listBookshelfBooks(
          sortBy: sort.key,
          sortOrder: sort.asc ? 'asc' : 'desc',
        );
      }
      if (gen != _reloadGeneration) return;
      books.value = AsyncState.data(data);
      Logging.debug(
        '[$this] reloadBooks() gen=$gen SUCCESS count=${data.length}',
      );
    } catch (e) {
      if (gen != _reloadGeneration) return;
      books.value = AsyncState.error(e);
    }
  }

  /// 搜索书籍（标题/作者模糊匹配）。
  Future<void> searchBooks(String keyword) async {
    final gen = ++_reloadGeneration;
    Logging.debug('[$this] searchBooks() gen=$gen keyword=$keyword');
    books.value = AsyncState.loading();
    try {
      final data = await book_api.searchBookshelfBooks(keyword: keyword);
      if (gen != _reloadGeneration) return;
      books.value = AsyncState.data(data);
    } catch (e) {
      if (gen != _reloadGeneration) return;
      books.value = AsyncState.error(e);
    }
  }

  /// 加载书籍列表和阅读进度。
  Future<void> loadBooks() async {
    await reloadBooks();
  }

  /// 切换分类
  void selectCategory(Category? category) {
    _categoryVM.selectCategory(category);
    searchKeyword.value = '';
    reloadBooks();
  }

  /// 切换状态筛选
  void selectStatus(BookStatus? status) {
    selectedStatus.value = status;
    reloadBooks();
  }

  /// 停止搜索，自动刷新恢复全量列表
  void stopSearch() {
    searchKeyword.value = '';
    reloadBooks();
  }

  /// 更新搜索关键词，自动触发搜索
  void updateSearchKeyword(String keyword) {
    searchKeyword.value = keyword;
    searchBooks(keyword);
  }

  /// 删除指定书籍及其封面文件。
  Future<bool> deleteBook(String id) async {
    try {
      await book_api.deleteBook(
        bookId: id,
        coversDir: AppConfig.instance.coverDir,
      );
      await loadBooks();
      return true;
    } catch (e, stack) {
      Logging.error(
        'deleteBook error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }


  /// 更新书籍分类
  Future<bool> updateBookCategories(String bookId, List<String> categoryIds) async {
    try {
      await category_api.setCategoriesForBook(
        bookId: bookId,
        categoryIds: categoryIds,
      );
      await loadBooks();
      return true;
    } catch (e, stack) {
      Logging.error(
        'updateBookCategories error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 批量更新书籍阅读状态。
  Future<void> batchUpdateStatus(
    Iterable<String> bookIds,
    String statusName,
  ) async {
    final status = BookStatus.values.byName(statusName);
    await book_api.batchUpdateBookStatus(
      bookIds: bookIds.toList(),
      status: status,
    );
    await loadBooks();
  }

  /// 批量设置书籍分类。
  Future<void> batchSetCategories(
    Iterable<String> bookIds,
    List<String> categoryIds,
  ) async {
    await book_api.batchSetCategoriesForBooks(
      bookIds: bookIds.toList(),
      categoryIds: categoryIds,
    );
    await loadBooks();
  }

  /// 切换单本书的阅读状态（reading ↔ planned）。
  Future<void> toggleBookStatus(String bookId, BookStatus currentStatus) async {
    final newStatus = currentStatus == BookStatus.reading
        ? BookStatus.planned
        : BookStatus.reading;
    await book_api.updateBookStatus(bookId: bookId, status: newStatus);
    await loadBooks();
  }

  /// 切换书籍的置顶状态。
  Future<void> toggleBookPin(String bookId, bool isPinned) async {
    await book_api.updateBookPin(bookId: bookId, isPinned: !isPinned);
    await loadBooks();
  }

  /// 切换列表/网格视图模式。
  void toggleViewMode() {
    _isListView.value = !_isListView.value;
  }

  /// 释放所有 signal 资源。
  void dispose() {
    showReadingProgress.dispose();
    defaultSortType.dispose();
    _isListView.dispose();
  }
}
