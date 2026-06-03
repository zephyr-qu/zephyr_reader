import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/cover.dart' as cover_api;
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
  late final showReadingProgress = persistedBool(
    _prefs, SettingsKeys.bookshelfShowProgress, true,
  );

  /// 显示最近阅读
  late final showRecentReading = persistedBool(
    _prefs, SettingsKeys.bookshelfShowRecent, true,
  );

  /// 默认排序方式
  late final defaultSortType = persistedEnumCustom(
    _prefs, SettingsKeys.bookshelfDefaultSort,
    BookshelfSortType.lastRead, BookshelfSortType.fromKey,
    (v) => v.key,
  );

  /// 是否使用列表视图（false=网格视图）
  late final isListView = persistedBool(
    _prefs, SettingsKeys.bookshelfIsListView, false,
  );

  /// 阅读进度映射 (bookId -> progress 0.0~1.0)
  final readingProgress = signal<Map<String, double>>({});

  /// 最近阅读的书籍
  final recentBooks = signal<List<Book>>([]);

  /// 瞬态反馈消息（Page 通过 useSignalEffect 消费）
  final feedback = signal<String?>(null);

  BookshelfViewModel(this._prefs) {
    _loadCategories();
    loadBooks();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await category_api.listCategories();
      categories.value = data.cast<Category>();
    } catch (e, stack) {
      Logging.error(
        'BookshelfViewModel._loadCategories error',
        exception: e,
        stackTrace: stack,
      );
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

  Future<bool> _safeAction(
    String label,
    FutureOr<bool> Function() action, {
    FutureOr<void> Function()? onSuccess,
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

  Future<bool> deleteBook(String id) => _safeAction('deleteBook', () async {
    await book_api.deleteBook(bookId: id);
    return true;
  }, onSuccess: loadBooks);

  /// 获取书籍详情
  Future<Book?> getBookDetail(String id) async {
    return await book_api.getBook(bookId: id);
  }

  // ==================== 分类管理 ====================

  Future<bool> addCategory({
    required String name,
    String color = '#FF5722',
    int sortOrder = 0,
  }) => _safeAction('addCategory', () async {
    await category_api.upsertCategory(
      name: name,
      color: color,
      sortOrder: sortOrder,
    );
    return true;
  }, onSuccess: _loadCategories);

  /// 更新分类
  Future<bool> updateCategory(Category category) =>
      _safeAction('updateCategory', () async {
        await category_api.upsertCategory(
          name: category.name,
          color: category.color,
          sortOrder: category.sortOrder,
          description: category.description,
        );
        return true;
      }, onSuccess: _loadCategories);

  /// 删除分类
  Future<bool> removeCategory(String id) => _safeAction(
    'removeCategory',
    () async {
      final category = await category_api.getCategory(categoryId: id);
      if (category == null) return false;
      await category_api.deleteCategory(categoryId: id);
      return true;
    },
    onSuccess: () async {
      await _loadCategories();
      if (selectedCategory.value?.id == id) {
        selectedCategory.value = categories.value.isEmpty
            ? null
            : categories.value.first;
      }
    },
  );

  /// 更新书籍分类
  Future<bool> updateBookCategories(String bookId, List<String> categoryIds) =>
      _safeAction('updateBookCategories', () async {
        await category_api.setCategoriesForBook(
          bookId: bookId,
          categoryIds: categoryIds,
        );
        return true;
      }, onSuccess: loadBooks);

  Future<bool> reExtractCover(String bookId, String filePath) async {
    if (!cover_api.supportsCoverExtraction(filePath: filePath)) {
      return false;
    }
    return _safeAction('reExtractCover', () async {
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
      final coverPath = await cover_api.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        outputDir: coverDir,
      );
      return coverPath.isNotEmpty;
    }, onSuccess: loadBooks);
  }

  Future<bool> importBook(String filePath) async {
    String? title;
    final ok = await _safeAction('importBook', () async {
      final parseResult = await core_api.parseBook(filePath: filePath);
      title = parseResult.bookInfo.title;
      await book_api.upsertBook(book: parseResult.bookInfo);
      return true;
    }, onSuccess: loadBooks);
    feedback.value = ok ? '已导入：$title' : '导入失败：$filePath';
    return ok;
  }

  Future<(int, String)> scanFolder(String folderPath) async {
    final extensions = {'.txt', '.epub', '.pdf'};
    final dir = Directory(folderPath);
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => extensions.contains(p.extension(f.path).toLowerCase()))
        .map((f) => f.path)
        .toList();
    if (files.isEmpty) {
      feedback.value = '未找到书籍文件';
      return (0, '未找到书籍文件');
    }
    var count = 0;
    for (final file in files) {
      try {
        final parseResult = await core_api.parseBook(filePath: file);
        await book_api.upsertBook(book: parseResult.bookInfo);
        count++;
      } catch (_) {}
    }
    await loadBooks();
    feedback.value = '扫描完成，导入了 $count 本书';
    return (count, '扫描完成，导入了 $count 本书');
  }

  Future<void> batchUpdateStatus(
    Iterable<String> bookIds,
    String statusName,
  ) async {
    final status = BookStatus.values.byName(statusName);
    for (final id in bookIds) {
      await book_api.updateBookStatus(bookId: id, status: status);
    }
    await loadBooks();
  }

  Future<void> batchSetCategories(
    Iterable<String> bookIds,
    List<String> categoryIds,
  ) async {
    for (final id in bookIds) {
      await category_api.setCategoriesForBook(
        bookId: id,
        categoryIds: categoryIds,
      );
    }
    await loadBooks();
  }

  Future<void> toggleBookStatus(String bookId, BookStatus currentStatus) async {
    final newStatus = currentStatus == BookStatus.reading
        ? BookStatus.planned
        : BookStatus.reading;
    await book_api.updateBookStatus(bookId: bookId, status: newStatus);
    await loadBooks();
  }

  Future<void> toggleBookPin(String bookId, bool isPinned) async {
    await book_api.updateBookPin(bookId: bookId, isPinned: !isPinned);
    await loadBooks();
  }

  void toggleViewMode() {
    isListView.value = !isListView.value;
  }
}
