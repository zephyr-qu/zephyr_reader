import 'package:injectable/injectable.dart';

import '../domain/search_repository.dart';

/// 搜索服务实现（示例，实际需要对接具体的小说源）
@LazySingleton(as: SearchRepository)
class SearchService implements SearchRepository {
  @override
  Future<List<SearchResult>> search(
    String keyword, {
    int page = 1,
    int pageSize = 20,
  }) async {
    // 这里是示例代码，实际需要对接具体的小说源API
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 返回模拟数据
    return [];
  }

  @override
  Future<SearchResult?> getDetail(String id) async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 返回模拟数据
    return null;
  }

  @override
  Future<List<String>> getChapters(String id) async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 返回模拟数据
    return [];
  }
}
