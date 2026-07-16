import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/domain/search/models.dart';

/// 书籍内搜索 ViewModel（单个搜索页独立使用，非单例）
class BookSearchViewModel {
  final String bookId;

  final query = signal('');
  final results = asyncSignal<List<SearchResult>>(AsyncState.loading());

  BookSearchViewModel({this.bookId = ''});

  /// 执行搜索，根据 [bookId] 是否为空决定搜索范围
  Future<void> search(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      results.value = AsyncState.data([]);
      return;
    }

    query.value = q;

    try {
      final list = bookId.isEmpty
          ? await search_api.searchAllBooks(query: q, limit: 50, offset: 0)
          : await search_api.search(bookId: bookId, query: q, limit: 50);
      results.value = AsyncState.data(list);
    } catch (e) {
      results.value = AsyncState.error(e);
    }
  }

  /// 清空搜索结果和查询
  void clear() {
    query.value = '';
    results.value = AsyncState.data([]);
  }

  /// 释放所有 signal 资源
  void dispose() {
    query.dispose();
    results.dispose();
  }
}
