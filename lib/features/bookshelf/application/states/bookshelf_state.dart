/// 书架状态管
library;

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/domain/models/book.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/bookshelf_filter.dart';

/// 书架状态类
@injectable
class BookshelfState {
  /// 视图模式
  final viewMode = signal(BookshelfViewMode.grid);

  /// 筛选条
  final filter = signal(const BookshelfFilter());

  /// 书籍列表
  final books = signal<List<Book>>([]);

  /// 加载状
  final isLoading = signal(false);

  /// 错误信息
  final error = signal<String?>(null);

  /// 选中书籍 ID 列表（批量操作）
  final selectedBookIds = signal<Set<int>>({});

  /// 是否处于批量选择模式
  final isSelectingMode = signal(false);

  /// 切换视图模式
  void toggleViewMode() {
    viewMode.value = viewMode.value == BookshelfViewMode.grid
        ? BookshelfViewMode.list
        : BookshelfViewMode.grid;
  }

  /// 设置视图模式
  void setViewMode(BookshelfViewMode mode) {
    viewMode.value = mode;
  }

  /// 更新筛选条
  void updateFilter(BookshelfFilter Function(BookshelfFilter) update) {
    final currentFilter = filter.value;
    final newFilter = update(currentFilter);
    filter.value = newFilter;
  }

  /// 设置搜索关键
  void setSearchKeyword(String? keyword) {
    updateFilter((f) => f.copyWith(keyword: keyword));
  }

  /// 设置状态筛
  void setStatusFilter(String? status) {
    updateFilter((f) => f.copyWith(status: status));
  }

  /// 设置格式筛
  void setFormatFilter(String? format) {
    updateFilter((f) => f.copyWith(format: format));
  }

  /// 设置排序方式
  void setSortType(BookshelfSortType type, {bool? ascending}) {
    updateFilter(
      (f) => f.copyWith(sortType: type, ascending: ascending ?? f.ascending),
    );
  }

  /// 切换排序方向
  void toggleSortOrder() {
    updateFilter((f) => f.copyWith(ascending: !f.ascending));
  }

  /// 重置筛
  void resetFilter() {
    filter.value = const BookshelfFilter();
  }

  /// 更新书籍列表
  void setBooks(List<Book> newBooks) {
    books.value = newBooks;
  }

  /// 添加书籍
  void addBook(Book book) {
    books.value = [...books.value, book];
  }

  /// 更新书籍
  void updateBook(Book book) {
    books.value = books.value.map((b) => b.id == book.id ? book : b).toList();
  }

  /// 删除书籍
  void removeBook(int bookId) {
    books.value = books.value.where((b) => b.id != bookId).toList();
    selectedBookIds.value.remove(bookId);
  }

  /// 切换选择状
  void toggleSelection(String bookId) {
    final newSet = Set<String>.from(selectedBookIds.value);
    if (newSet.contains(bookId)) {
      newSet.remove(bookId);
    } else {
      newSet.add(bookId);
    }
    selectedBookIds.value = newSet.cast<int>();
  }

  /// 清除选择
  void clearSelection() {
    selectedBookIds.value = {};
    isSelectingMode.value = false;
  }

  /// 全
  void selectAll() {
    selectedBookIds.value = books.value.map((b) => b.id).toSet();
  }

  /// 切换批量选择模式
  void toggleSelectingMode() {
    isSelectingMode.value = !isSelectingMode.value;
    if (!isSelectingMode.value) {
      clearSelection();
    }
  }

  /// 获取选中书籍数量
  int get selectedCount => selectedBookIds.value.length;

  /// 是否已选中某书
  bool isSelected(int bookId) => selectedBookIds.value.contains(bookId);
}
