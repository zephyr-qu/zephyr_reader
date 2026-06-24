import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';

/// 滑动窗口页块缓存；center±window 保留，其余驱逐。
class PageBlocksCache {
  static const int windowRadius = 5;

  final Map<int, List<PageBlockSlice>> _cache = {};

  List<PageBlockSlice>? get(int pageIndex) => _cache[pageIndex];

  void put(int pageIndex, List<PageBlockSlice> blocks) {
    _cache[pageIndex] = blocks;
  }

  void clear() => _cache.clear();

  void trimAround(int centerPage) {
    _cache.removeWhere((key, _) => (key - centerPage).abs() > windowRadius);
  }

  bool containsKey(int pageIndex) => _cache.containsKey(pageIndex);
}
