import 'dart:convert';

/// 翻译缓存（内存 LRU）。
///
/// 以章节 index + 内容哈希为键，避免同一章节重复翻译。
/// 固定最大条目数，超出时淘汰最久未使用的条目。
class BilingualCache {
  final int _maxEntries;

  // Linked-hash-map 风格：插入/访问时更新顺序
  final _cache = <String, _CacheEntry>{};

  BilingualCache({this._maxEntries = 20});

  /// 生成缓存键。
  String _key(int chapterIndex, String content) {
    final hash = sha256(content);
    return '$chapterIndex:$hash';
  }

  /// 获取缓存的翻译，命中时更新访问时间。
  String? get(int chapterIndex, String content) {
    final key = _key(chapterIndex, content);
    final entry = _cache[key];
    if (entry == null) return null;
    entry.lastAccess = DateTime.now();
    return entry.translated;
  }

  /// 存入翻译结果。
  void put(int chapterIndex, String content, String translated) {
    if (_cache.length >= _maxEntries) {
      _evict();
    }
    _cache[_key(chapterIndex, content)] = _CacheEntry(translated);
  }

  /// 失效指定章节的所有缓存。
  void invalidateChapter(int chapterIndex) {
    _cache.removeWhere((key, _) => key.startsWith('$chapterIndex:'));
  }

  /// 清空全部缓存。
  void clear() => _cache.clear();

  /// 淘汰最久未访问的条目。
  void _evict() {
    if (_cache.isEmpty) return;
    final oldest = _cache.entries.reduce(
      (a, b) => a.value.lastAccess.isBefore(b.value.lastAccess) ? a : b,
    );
    _cache.remove(oldest.key);
  }

  /// 简单 Adler-32 摘要（纯 Dart，无 crypto 依赖）。
  static String sha256(String input) {
    final bytes = utf8.encode(input);
    // 用 Adler-32 近似哈希（足够区分章节内容变更）
    var a = 1, b = 0;
    for (final byte in bytes) {
      a = (a + byte) % 65521;
      b = (b + a) % 65521;
    }
    return '${b * 65536 + a}';
  }
}

class _CacheEntry {
  final String translated;
  DateTime lastAccess;

  _CacheEntry(this.translated) : lastAccess = DateTime.now();
}
