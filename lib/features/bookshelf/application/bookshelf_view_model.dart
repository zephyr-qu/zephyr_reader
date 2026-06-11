import 'dart:async';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/app_config.dart';
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
import 'package:zephyr_reader/features/bookshelf/application/category_view_model.dart';

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
  late final isListView = persistedBool(
    _prefs,
    SettingsKeys.bookshelfIsListView,
    false,
  );

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

  /// 重新提取并保存书籍封面。
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

  /// 从文件导入书籍（解析并存入数据库）。
  Future<bool> importBook(String filePath) async {
    final ok = await _safeAction('importBook', () async {
      final parseResult = await core_api.parseBook(filePath: filePath);
      await book_api.upsertBook(book: parseResult.bookInfo);
      // 导入后自动提取封面到磁盘
      await _extractCover(parseResult.bookInfo.bookId, filePath);
      return true;
    }, onSuccess: loadBooks);
    return ok;
  }

  /// 提取书籍封面并保存到磁盘，失败不阻塞导入流程。
  Future<void> _extractCover(String bookId, String filePath) async {
    if (!cover_api.supportsCoverExtraction(filePath: filePath)) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
      await cover_api.extractAndSaveCover(
        bookId: bookId,
        filePath: filePath,
        outputDir: coverDir,
      );
    } catch (_) {
      // 封面提取失败不影响导入结果
    }
  }

  /// 并发上限
  static const int _scanConcurrency = 4;

  /// 扫描文件夹并将发现的书籍文件导入数据库。
  ///
  /// [onProgress] 可选进度回调，接收 (done, total) 用于 UI 展示。
  /// 返回 (successCount, failCount)。
  Future<(int, int)> scanFolder(
    String folderPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final extensions = {'.txt', '.epub', '.pdf'};
    final dir = Directory(folderPath);
    final files = await dir
        .list(recursive: true)
        .where((e) => e is File)
        .cast<File>()
        .where((f) => extensions.contains(p.extension(f.path).toLowerCase()))
        .map((f) => f.path)
        .toList();
    if (files.isEmpty) {
      return (0, 0);
    }

    final total = files.length;
    var done = 0;
    var success = 0;
    var fail = 0;
    onProgress?.call(0, total);

    final sem = _Semaphore(_scanConcurrency);
    await Future.wait(
      files.map(
        (file) => sem.acquire(() async {
          try {
            final parseResult = await core_api.parseBook(filePath: file);
            final bookId = parseResult.bookInfo.bookId;
            await book_api.upsertBook(book: parseResult.bookInfo);
            await _extractCover(bookId, file);
            success++;
          } catch (e, stack) {
            fail++;
            Logging.error(
              'scanFolder error: $file',
              exception: e,
              stackTrace: stack,
            );
          } finally {
            done++;
            onProgress?.call(done, total);
          }
        }),
      ),
    );

    _invalidateCache();
    await reloadBooks();
    return (success, fail);
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
    isListView.value = !isListView.value;
  }

  /// 释放所有 signal 资源。
  void dispose() {
    showReadingProgress.dispose();
    defaultSortType.dispose();
    isListView.dispose();
  }
}

/// 简单信号量，限制并发数。
class _Semaphore {
  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this._max);

  Future<T> acquire<T>(Future<T> Function() fn) async {
    if (_count < _max) {
      _count++;
      try {
        return await fn();
      } finally {
        _release();
      }
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    return acquire(fn);
  }

  void _release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _count--;
    }
  }
}
