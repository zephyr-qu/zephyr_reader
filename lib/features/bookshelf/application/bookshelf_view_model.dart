import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/category.dart' as category_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架排序方式枚举。
enum BookshelfSortType {
  lastRead('last_read'),
  createdAt('created_at'),
  title('title'),
  author('author'),
  progress('progress');

  final String key;
  const BookshelfSortType(this.key);

  static BookshelfSortType fromKey(String key) {
    return BookshelfSortType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => BookshelfSortType.lastRead,
    );
  }
}

@lazySingleton
class BookshelfViewModel {
  final SharedPreferences _prefs;
  final CategoryViewModel _categoryVM;
  static int _instanceCounter = 0;
  final int _instanceId;

  /// 自增世代计数器
  int _reloadGeneration = 0;

  /// 全量书籍列表缓存，避免无筛选时重复 FFI 调用。
  List<Book>? _cachedBooks;
  bool _cacheDirty = true;

  void _invalidateCache() {
    _cacheDirty = true;
    _cachedBooks = null;
  }

  /// 所有书籍
  final books = asyncSignal<List<Book>>(AsyncState.loading());
  CategoryViewModel get categoryVM => _categoryVM;

  /// 当前选中的阅读状态
  final selectedStatus = signal<BookStatus?>(null);

  /// 搜索关键词
  final searchKeyword = signal<String>('');

  /// 是否在搜索模式
  final isSearching = signal<bool>(false);

  /// 显示阅读进度
  late final showReadingProgress = persistedBool(
    _prefs,
    SettingsKeys.bookshelfShowProgress,
    true,
  );

  /// 默认排序方式
  late final defaultSortType = persistedEnumCustom(
    _prefs,
    SettingsKeys.bookshelfDefaultSort,
    BookshelfSortType.lastRead,
    BookshelfSortType.fromKey,
    (v) => v.key,
  );

  /// 是否使用列表视图（false=网格视图）
  late final _isListView = persistedBool(
    _prefs,
    SettingsKeys.bookshelfIsListView,
    false,
  );

  /// 列表/网格视图模式（持久化）。页面消费此信号。
  Signal<bool> get isListView => _isListView.signal;

  /// 阅读进度映射 (bookId -> progress 0.0~1.0)
  final readingProgress = asyncSignal<Map<String, double>>(
    AsyncState.loading(),
  );

  /// 瞬态反馈消息（Page 通过 useSignalEffect 消费）
  final feedback = signal<String?>(null);

  BookshelfViewModel(this._prefs, this._categoryVM)
    : _instanceId = ++_instanceCounter;
  @override
  String toString() => 'BookshelfVM#$_instanceId';

  /// 加载书籍列表 + 排序（最常用的刷新）
  Future<void> reloadBooks() async {
    final gen = ++_reloadGeneration;
    final cacheDirty = _cacheDirty;
    final cachedCount = _cachedBooks?.length ?? -1;
    Logging.debug(
      '[$this] reloadBooks() gen=$gen category=${_categoryVM.selectedCategory.value?.id} status=${selectedStatus.value?.name} cacheDirty=$cacheDirty cachedCount=$cachedCount',
    );
    books.value = AsyncState.loading();
    try {
      List<Book> data;

      if (isSearching.value && searchKeyword.value.isNotEmpty) {
        data = await book_api.searchBooks(keyword: searchKeyword.value);
      } else {
        final category = _categoryVM.selectedCategory.value;
        final status = selectedStatus.value;
        if (category != null && status != null) {
          // Both filters: fetch by category, filter status in Dart
          data = await category_api.listBooksByCategory(
            categoryId: category.id,
          );
          data = data.where((b) => b.status == status).toList();
        } else if (category != null) {
          data = await category_api.listBooksByCategory(
            categoryId: category.id,
          );
        } else if (status != null) {
          data = await book_api.listBooksByStatus(status: status);
        } else {
          // 无筛选时使用缓存，避免重复全量 FFI 调用
          if (_cacheDirty || _cachedBooks == null) {
            data = await book_api.listBooks();
            _cachedBooks = data;
            _cacheDirty = false;
          } else {
            data = _cachedBooks!;
          }
        }
      }

      data = List.from(data);

      data.sort((a, b) {
        // 置顶书始终排在最前
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
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
            final pa = (readingProgress.value.value ?? {})[a.bookId] ?? 0;
            final pb = (readingProgress.value.value ?? {})[b.bookId] ?? 0;
            return pb.compareTo(pa);
          case BookshelfSortType.createdAt:
            return -(a.addedAt).compareTo(b.addedAt);
        }
      });

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

  /// 刷新阅读进度
  Future<void> reloadProgress() async {
    try {
      final allProgress = await progress_api.listAllProgresses();
      final progressMap = <String, double>{};
      for (final item in allProgress) {
        if (item.progress != null) {
          progressMap[item.book.bookId] = item.progress!.progress;
        }
      }
      readingProgress.value = AsyncState.data(progressMap);
    } catch (e) {
      readingProgress.value = AsyncState.error(e);
    }
  }

  /// 加载书籍列表和阅读进度。
  Future<void> loadBooks() async {
    Logging.debug('[$this] loadBooks() called');
    _invalidateCache();
    await reloadBooks();
    await reloadProgress();
    Logging.debug(
      '[$this] loadBooks() completed, books count=${(books.value.value ?? []).length}',
    );
  }

  /// 安全执行操作，捕获异常并记录日志，成功后可选执行回调。
  Future<bool> _safeAction(
    String label,
    Future<bool> Function() action, {
    Future<void> Function()? onSuccess,
  }) async {
    try {
      final ok = await action();
      if (!ok) return false;
      if (onSuccess != null) await onSuccess();
      return true;
    } catch (e, stack) {
      Logging.error(
        'BookshelfViewModel.$label error',
        exception: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// 切换分类
  void selectCategory(Category? category) {
    _categoryVM.selectCategory(category);
    isSearching.value = false;
    searchKeyword.value = '';
    reloadBooks();
  }

  /// 切换状态筛选
  void selectStatus(BookStatus? status) {
    selectedStatus.value = status;
    isSearching.value = false;
    reloadBooks();
  }

  /// 开始搜索
  void startSearch() {
    isSearching.value = true;
  }

  /// 停止搜索，自动刷新恢复全量列表
  void stopSearch() {
    isSearching.value = false;
    searchKeyword.value = '';
    reloadBooks();
  }

  /// 更新搜索关键词，自动触发搜索
  void updateSearchKeyword(String keyword) {
    searchKeyword.value = keyword;
    reloadBooks();
  }

  /// 删除指定书籍及其封面文件。
  Future<bool> deleteBook(String id) => _safeAction('deleteBook', () async {
    await book_api.deleteBook(
      bookId: id,
      coversDir: AppConfig.instance.coverDir,
    );
    return true;
  }, onSuccess: loadBooks);

  /// 获取书籍详情
  Future<Book?> getBookDetail(String id) async {
    return await book_api.getBook(bookId: id);
  }

  /// 更新书籍分类
  Future<bool> updateBookCategories(String bookId, List<String> categoryIds) =>
      _safeAction('updateBookCategories', () async {
        await category_api.setCategoriesForBook(
          bookId: bookId,
          categoryIds: categoryIds,
        );
        return true;
      }, onSuccess: loadBooks);

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
    _invalidateCache();
    await reloadBooks();
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
    _invalidateCache();
    await reloadBooks();
  }

  /// 切换单本书的阅读状态（reading ↔ planned）。
  Future<void> toggleBookStatus(String bookId, BookStatus currentStatus) async {
    final newStatus = currentStatus == BookStatus.reading
        ? BookStatus.planned
        : BookStatus.reading;
    await book_api.updateBookStatus(bookId: bookId, status: newStatus);
    _invalidateCache();
    await reloadBooks();
  }

  /// 切换书籍的置顶状态。
  Future<void> toggleBookPin(String bookId, bool isPinned) async {
    await book_api.updateBookPin(bookId: bookId, isPinned: !isPinned);
    _invalidateCache();
    await reloadBooks();
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
