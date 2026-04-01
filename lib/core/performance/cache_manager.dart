/// 阅读器缓存管理器
///
/// 提供章节内容缓存、图片缓存、布局缓存等功能，
/// 优化大文件加载性能和内存使用
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/logging.dart';

/// 缓存条目
class CacheEntry<T> {
  final T value;
  final DateTime createdAt;
  final int size;
  final int accessCount;

  CacheEntry({
    required this.value,
    required this.createdAt,
    this.size = 1,
    this.accessCount = 0,
  });

  CacheEntry<T> copyWith({
    T? value,
    DateTime? createdAt,
    int? size,
    int? accessCount,
  }) {
    return CacheEntry<T>(
      value: value ?? this.value,
      createdAt: createdAt ?? this.createdAt,
      size: size ?? this.size,
      accessCount: accessCount ?? this.accessCount,
    );
  }
}

/// LRU 缓存实现
class LruCache<K, T> {
  final int maxSize;
  final Map<K, CacheEntry<T>> _cache;
  final Queue<K> _accessOrder;

  LruCache({required this.maxSize}) : _cache = {}, _accessOrder = Queue();

  /// 获取缓存
  T? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // 更新访问顺序
    _accessOrder.remove(key);
    _accessOrder.addLast(key);

    return entry.value;
  }

  /// 设置缓存
  void put(K key, T value, {int size = 1}) {
    // 如果已存在，先移除
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // 如果缓存已满，移除最久未使用
    while (_cache.length >= maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeFirst();
      _cache.remove(oldestKey);
    }

    // 添加新条目
    _cache[key] = CacheEntry(
      value: value,
      createdAt: DateTime.now(),
      size: size,
    );
    _accessOrder.addLast(key);
  }

  /// 移除缓存
  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// 获取缓存大小
  int get length => _cache.length;

  /// 获取缓存占用
  int get totalSize => _cache.values.fold(0, (sum, entry) => sum + entry.size);

  /// 获取所有键
  Iterable<K> get keys => _cache.keys;

  /// 获取访问队列
  Queue<K> get accessOrder => _accessOrder;
}

/// 章节内容缓存
///
/// 提供章节内容的二级缓存（内存 + 磁盘），优化阅读器加载性能
class ChapterContentCache {
  static ChapterContentCache? _instance;
  late final LruCache<String, String> _cache;
  late final Directory _cacheDir;
  bool _isInitialized = false;

  /// 最大内存缓存章节数
  static const int maxMemoryCacheSize = 100;

  /// 最大磁盘缓存大小（100MB）
  static const int maxDiskCacheSize = 100 * 1024 * 1024;

  ChapterContentCache._() {
    // 使用内存缓存（最多 100 章）
    _cache = LruCache(maxSize: maxMemoryCacheSize);
    _initCacheDir();
  }

  static ChapterContentCache get instance {
    _instance ??= ChapterContentCache._();
    return _instance!;
  }

  Future<void> _initCacheDir() async {
    try {
      final tempDir = await getTemporaryDirectory();
      _cacheDir = Directory(p.join(tempDir.path, 'chapter_cache'));
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }
      _isInitialized = true;
      Logging.debug('章节缓存目录初始化完成：${_cacheDir.path}');
    } catch (e) {
      Logging.warning('章节缓存目录初始化失败：$e');
      _isInitialized = false;
    }
  }

  /// 确保缓存目录已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initCacheDir();
    }
  }

  /// 获取缓存键
  String _getCacheKey(int bookId, int chapterId) =>
      'book_${bookId}_chapter_$chapterId';

  /// 获取章节内容
  ///
  /// [bookId] 书籍 ID
  /// [chapterId] 章节 ID
  ///
  /// 返回章节内容，如果缓存未命中则返回 null
  Future<String?> get(int bookId, int chapterId) async {
    await _ensureInitialized();

    final key = _getCacheKey(bookId, chapterId);

    // 先尝试内存缓存
    final cached = _cache.get(key);
    if (cached != null) {
      Logging.debug('章节内存缓存命中：$key');
      return cached;
    }

    // 尝试磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
    if (await cacheFile.exists()) {
      Logging.debug('章节磁盘缓存命中：$key');
      try {
        final content = await cacheFile.readAsString();
        // 写入内存缓存
        _cache.put(key, content);
        return content;
      } catch (e) {
        Logging.warning('读取缓存文件失败：$e');
        // 文件损坏，删除它
        await cacheFile.delete();
      }
    }

    return null;
  }

  /// 设置章节内容
  ///
  /// [bookId] 书籍 ID
  /// [chapterId] 章节 ID
  /// [content] 章节内容
  Future<void> put(int bookId, int chapterId, String content) async {
    await _ensureInitialized();

    final key = _getCacheKey(bookId, chapterId);

    // 写入内存缓存
    _cache.put(key, content);

    // 写入磁盘缓存
    try {
      final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsString(content);
      Logging.debug('章节缓存已写入：$key');
    } catch (e) {
      Logging.warning('写入缓存文件失败：$e');
    }
  }

  /// 批量设置章节内容
  ///
  /// [bookId] 书籍 ID
  /// [chapters] 章节 ID 到内容的映射
  Future<void> putAll(int bookId, Map<int, String> chapters) async {
    await _ensureInitialized();

    for (final entry in chapters.entries) {
      await put(bookId, entry.key, entry.value);
    }
    Logging.debug('批量缓存已写入：bookId=$bookId, count=${chapters.length}');
  }

  /// 移除章节缓存
  ///
  /// [bookId] 书籍 ID
  /// [chapterId] 章节 ID
  Future<void> remove(int bookId, int chapterId) async {
    await _ensureInitialized();

    final key = _getCacheKey(bookId, chapterId);
    _cache.remove(key);

    try {
      final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (e) {
      Logging.warning('删除缓存文件失败：$e');
    }
  }

  /// 清除书籍的所有缓存
  ///
  /// [bookId] 书籍 ID
  Future<void> clearBook(int bookId) async {
    await _ensureInitialized();

    final prefix = 'book_${bookId}_';

    // 从内存缓存删除
    final keysToRemove = <String>[];
    for (final key in _cache._cache.keys) {
      if (key.toString().startsWith(prefix)) {
        keysToRemove.add(key.toString());
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    // 从磁盘缓存删除
    try {
      if (await _cacheDir.exists()) {
        await for (final entity in _cacheDir.list()) {
          if (entity is File && p.basename(entity.path).startsWith(prefix)) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      Logging.warning('删除磁盘缓存失败：$e');
    }

    Logging.debug('书籍章节缓存已清除：bookId=$bookId');
  }

  /// 清除所有缓存
  Future<void> clearAll() async {
    await _ensureInitialized();

    _cache.clear();

    try {
      if (await _cacheDir.exists()) {
        await _cacheDir.delete(recursive: true);
      }
      await _cacheDir.create(recursive: true);
      Logging.debug('所有章节缓存已清除');
    } catch (e) {
      Logging.warning('清除磁盘缓存失败：$e');
    }
  }

  /// 获取缓存统计
  CacheStats getStats() {
    return CacheStats(
      memoryCacheSize: _cache.length,
      memoryCacheTotalSize: _cache.totalSize,
      diskCachePath: _cacheDir.path,
    );
  }

  /// 检查章节是否已缓存
  Future<bool> isCached(int bookId, int chapterId) async {
    await _ensureInitialized();

    final key = _getCacheKey(bookId, chapterId);

    // 检查内存缓存
    if (_cache._cache.containsKey(key)) {
      return true;
    }

    // 检查磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
    return await cacheFile.exists();
  }

  /// 获取所有缓存的章节键
  List<String> getCachedKeys() {
    return _cache._cache.keys.map((k) => k.toString()).toList();
  }

  /// 获取磁盘缓存大小（字节）
  Future<int> getDiskCacheSize() async {
    await _ensureInitialized();

    try {
      if (!await _cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in _cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      Logging.warning('获取磁盘缓存大小失败：$e');
      return 0;
    }
  }

  /// 修剪缓存到指定大小
  ///
  /// [maxSize] 最大缓存章节数
  Future<void> trimToSize(int maxSize) async {
    await _ensureInitialized();

    // 调整 LRU 缓存大小
    while (_cache.length > maxSize) {
      // LRU 会自动移除最久未使用的
      final oldestKey = _cache._accessOrder.first;
      _cache.remove(oldestKey);
    }
    Logging.debug('缓存已修剪到 $maxSize 个条目');
  }

  /// 清除所有布局缓存
  ///
  /// 用于在阅读器设置变化时（如字体大小、行间距变化）
  /// 清除所有已缓存的布局信息
  Future<void> clearLayoutCache() async {
    await _ensureInitialized();

    // 清除内存缓存
    _cache.clear();

    // 清除磁盘缓存
    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create(recursive: true);
    }

    Logging.debug('所有布局缓存已清除');
  }
}

/// 图片缓存
class ImageCache {
  static ImageCache? _instance;
  late final LruCache<String, ui.Image> _memoryCache;
  late final Directory _cacheDir;

  ImageCache._({int maxMemorySize = 50}) {
    _memoryCache = LruCache(maxSize: maxMemorySize);
    _initCacheDir();
  }

  static ImageCache get instance {
    _instance ??= ImageCache._();
    return _instance!;
  }

  Future<void> _initCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(tempDir.path, 'image_cache'));
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
  }

  /// 获取缓存
  String _getCacheKey(String imagePath) => imagePath.hashCode.toString();

  /// 获取图片
  Future<ui.Image?> get(String imagePath) async {
    final key = _getCacheKey(imagePath);

    // 先尝试内存缓存
    final cached = _memoryCache.get(key);
    if (cached != null) {
      Logging.debug('图片内存缓存命中：$imagePath');
      return cached;
    }

    // 尝试磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.png'));
    if (await cacheFile.exists()) {
      Logging.debug('图片磁盘缓存命中：$imagePath');
      final bytes = await cacheFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    }

    return null;
  }

  /// 设置图片缓存
  Future<void> put(String imagePath, ui.Image image) async {
    final key = _getCacheKey(imagePath);

    // 写入内存缓存
    _memoryCache.put(key, image);

    // 写入磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.png'));
    await cacheFile.parent.create(recursive: true);

    // 将图片编码为 PNG
    final byteData = await image.toByteData();
    if (byteData != null) {
      await cacheFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    Logging.debug('图片缓存已写入：$imagePath');
  }

  /// 移除图片缓存
  Future<void> remove(String imagePath) async {
    final key = _getCacheKey(imagePath);
    _memoryCache.remove(key);

    final cacheFile = File(p.join(_cacheDir.path, '$key.png'));
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
  }

  /// 清除所有图片缓存
  Future<void> clearAll() async {
    _memoryCache.clear();

    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create(recursive: true);
    }

    Logging.debug('所有图片缓存已清除');
  }

  /// 获取图片缓存统计
  CacheStats getStats() {
    return CacheStats(
      memoryCacheSize: _memoryCache.length,
      memoryCacheTotalSize: _memoryCache.totalSize,
      diskCachePath: _cacheDir.path,
    );
  }
}

/// 缓存统计信息
class CacheStats {
  final int memoryCacheSize;
  final int memoryCacheTotalSize;
  final String diskCachePath;

  CacheStats({
    required this.memoryCacheSize,
    required this.memoryCacheTotalSize,
    required this.diskCachePath,
  });

  @override
  String toString() {
    return 'CacheStats(memory: $memoryCacheSize entries, $memoryCacheTotalSize bytes, disk: $diskCachePath)';
  }
}

/// 预加载管理器
class PrefetchManager {
  final List<int> _prefetchQueue;
  bool _isPrefetching = false;

  PrefetchManager() : _prefetchQueue = [];

  /// 添加预加载任务
  void addPrefetchTask(int chapterId) {
    if (!_prefetchQueue.contains(chapterId)) {
      _prefetchQueue.add(chapterId);
    }
    _startPrefetch();
  }

  /// 开始预加载
  Future<void> _startPrefetch() async {
    if (_isPrefetching || _prefetchQueue.isEmpty) return;

    _isPrefetching = true;

    while (_prefetchQueue.isNotEmpty) {
      final chapterId = _prefetchQueue.removeAt(0);
      // 这里需要配合阅读器 ViewModel 获取章节内容
      // 由于依赖关系复杂，暂时不实现具体内容获取
      Logging.debug('预加载章节：$chapterId');
    }

    _isPrefetching = false;
  }

  /// 取消所有预加载任务
  void cancelAll() {
    _prefetchQueue.clear();
    _isPrefetching = false;
  }
}
