import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';

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

  /// 将编辑后的 Book 写回当前 state（用于编辑元数据后的乐观更新）。
  /// 集中在此处以便未来加入持久化、通知等副作用。调用方不应直接写入 [state]。
  void applyEditedBook(Book updated) {
    final current = state.value;
    if (current is AsyncData<book_api.BookDetail>) {
      state.value = AsyncState.data(current.value.copyWith(book: updated));
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    state.dispose();
  }
}
