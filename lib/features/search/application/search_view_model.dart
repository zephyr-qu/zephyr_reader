import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../domain/search_repository.dart';

/// 搜索视图模型
@injectable
class SearchViewModel {
  final SearchRepository _repo;

  /// 搜索关键词
  final keyword = signal<String>('');

  /// 搜索结果
  final results = asyncSignal<List<SearchResult>>(AsyncState.data([]));

  /// 是否正在搜索
  final isSearching = signal<bool>(false);

  /// 当前页码
  final currentPage = signal<int>(1);

  /// 是否有更多数据
  final hasMore = signal<bool>(false);

  SearchViewModel(this._repo);

  /// 执行搜索
  Future<void> search({bool loadMore = false}) async {
    if (keyword.value.isEmpty) {
      results.value = AsyncState.data([]);
      return;
    }

    if (!loadMore) {
      currentPage.value = 1;
    }

    isSearching.value = true;
    results.value = AsyncState.loading();

    try {
      final data = await _repo.search(
        keyword.value,
        page: currentPage.value,
      );

      if (loadMore) {
        final current = results.value.value ?? [];
        results.value = AsyncState.data([...current, ...data]);
      } else {
        results.value = AsyncState.data(data);
      }

      hasMore.value = data.length >= 20; // 假设每页20条
    } catch (e) {
      results.value = AsyncState.error(e);
    } finally {
      isSearching.value = false;
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (!hasMore.value || isSearching.value) return;

    currentPage.value++;
    await search(loadMore: true);
  }

  /// 更新搜索关键词
  void updateKeyword(String value) {
    keyword.value = value;
  }

  /// 清空搜索结果
  void clear() {
    keyword.value = '';
    results.value = AsyncState.data([]);
    currentPage.value = 1;
  }
}