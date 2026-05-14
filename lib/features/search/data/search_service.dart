import 'package:injectable/injectable.dart';

/// 搜索结果模型
class SearchResult {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final int totalChapters;
  final String source;

  SearchResult({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    required this.totalChapters,
    required this.source,
  });
}

/// 搜索服务实现（示例，实际需要对接具体的小说源）
@LazySingleton()
class SearchRepository {
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

  Future<SearchResult?> getDetail(String id) async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 返回模拟数据
    return null;
  }

  Future<List<String>> getChapters(String id) async {
    // 模拟网络请求延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 返回模拟数据
    return [];
  }
}
