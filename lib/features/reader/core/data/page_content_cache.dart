/// 滑动窗口页文本缓存；center±window 保留，其余驱逐。
class PageContentCache {
  static const int windowRadius = 5;

  final Map<int, String> _cache = {};

  /// 获取指定页的缓存文本。
  String? get(int pageIndex) => _cache[pageIndex];

  /// 缓存指定页的文本内容。
  void put(int pageIndex, String content) {
    _cache[pageIndex] = content;
  }

  /// 同 [put]，语义别名。
  void warm(int pageIndex, String content) => put(pageIndex, content);

  /// 清空所有缓存。
  void clear() => _cache.clear();

  /// 保留 centerPage±[windowRadius] 范围内的页面，其余驱逐。
  void trimAround(int centerPage) {
    _cache.removeWhere((key, _) => (key - centerPage).abs() > windowRadius);
  }

  /// 是否包含指定页的缓存。
  bool containsKey(int pageIndex) => _cache.containsKey(pageIndex);

  /// 当前缓存的页数量。
  int get length => _cache.length;

  /// 按条件移除缓存条目。
  void removeWhere(bool Function(int key, String value) test) =>
      _cache.removeWhere(test);
}
