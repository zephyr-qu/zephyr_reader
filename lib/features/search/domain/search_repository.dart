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

/// 搜索仓库接口
abstract class SearchRepository {
  /// 搜索小说
  Future<List<SearchResult>> search(
    String keyword, {
    int page = 1,
    int pageSize = 20,
  });

  /// 获取小说详情
  Future<SearchResult?> getDetail(String id);

  /// 获取章节列表
  Future<List<String>> getChapters(String id);
}
