import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/app_config.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书籍详情 ViewModel。
///
/// 加载并管理书籍的详细信息、阅读进度、笔记统计、章节列表等。
class BookDetailViewModel {
  BookDetailViewModel({required this.bookId});

  final state = asyncSignal<book_api.BookDetail>(AsyncState.loading());

  final String bookId;

  /// 从 Rust 侧加载书籍详情，包括进度、笔记统计、章节、分类、阅读会话和生词列表。
  Future<void> loadData() async {
    try {
      final detail = await book_api.getBookDetail(bookId: bookId);
      state.value = AsyncState.data(detail);
    } catch (e) {
      state.value = AsyncState.error(e);
    }
  }

  /// 删除本书及封面文件。
  Future<void> deleteBook() async {
    await book_api.deleteBook(
      bookId: bookId,
      coversDir: AppConfig.instance.coverDir,
    );
  }

  /// 更新书籍元数据（标题、作者、描述等）。
  void updateMetadata(Book Function(Book) updater) {
    final current = state.value;
    if (current is AsyncData<book_api.BookDetail>) {
      state.value = AsyncState.data(
        current.value.copyWith(book: updater(current.value.book)),
      );
    }
  }

  /// 释放所有 signal 资源。
  void dispose() {
    state.dispose();
  }
}
