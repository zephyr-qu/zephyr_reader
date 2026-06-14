import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;

/// 书籍详情 ViewModel。
///
/// 加载并管理书籍的详细信息、阅读进度、笔记统计、章节列表等。
class BookDetailViewModel {
  BookDetailViewModel({required this.bookId});

  final state = asyncSignal<book_api.BookDetail>(AsyncState.loading());

  final String bookId;

  /// 从 Rust 侧加载书籍详情，包括进度、笔记统计、章节、分类、阅读会话和生词列表。
  Future<void> loadData() async {
    await state.loadAsync(
      () => book_api.getBookDetail(bookId: bookId),
      label: '加载书籍详情',
    );
  }


  /// 释放所有 signal 资源。
  void dispose() {
    state.dispose();
  }
}
