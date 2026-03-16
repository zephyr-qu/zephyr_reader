/// 阅读器缓存管�?///
/// 提供章节内容缓存、图片缓存、布局缓存等功能，
/// 优化大文件加载性能和内存使用�?
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// 获取缓存�?
  T? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // 更新访问顺序
    _accessOrder.remove(key);
    _accessOrder.addLast(key);

    return entry.value;
  }

  /// 设置缓存�?
  void put(K key, T value, {int size = 1}) {
    // 如果已存在，先移�?
    if (_cache.containsKey(key)) {
      _accessOrder.remove(key);
    }

    // 如果缓存已满，移除最久未使用�?
    while (_cache.length >= maxSize && _accessOrder.isNotEmpty) {
      final oldestKey = _accessOrder.removeFirst();
      _cache.remove(oldestKey);
    }

    // 添加新条�?
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

  /// 清除所有缓�?
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// 获取缓存大小
  int get length => _cache.length;

  /// 获取缓存占用
  int get totalSize => _cache.values.fold(0, (sum, entry) => sum + entry.size);

  /// 检查是否包含某个键
  bool containsKey(K key) => _cache.containsKey(key);
}

/// 章节内容缓存
class ChapterContentCache {
  static ChapterContentCache? _instance;
  late final LruCache<String, String> _cache;
  late final Directory _cacheDir;

  ChapterContentCache._() {
    // 使用内存缓存（最�?100 章）
    _cache = LruCache(maxSize: 100);
    _initCacheDir();
  }

  static ChapterContentCache get instance {
    _instance ??= ChapterContentCache._();
    return _instance!;
  }

  Future<void> _initCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    _cacheDir = Directory(p.join(tempDir.path, 'chapter_cache'));
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
  }

  /// 获取缓存�?
  String _getCacheKey(int bookId, int chapterId) =>
      'book_${bookId}_chapter_$chapterId';

  /// 获取章节内容
  Future<String?> get(int bookId, int chapterId) async {
    final key = _getCacheKey(bookId, chapterId);

    // 先尝试内存缓�?
    final cached = _cache.get(key);
    if (cached != null) {
      debugPrint('内存缓存命中�?key');
      return cached;
    }

    // 尝试磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
    if (await cacheFile.exists()) {
      debugPrint('磁盘缓存命中�?key');
      final content = await cacheFile.readAsString();
      // 写入内存缓存
      _cache.put(key, content);
      return content;
    }

    return null;
  }

  /// 设置章节内容
  Future<void> put(int bookId, int chapterId, String content) async {
    final key = _getCacheKey(bookId, chapterId);

    // 写入内存缓存
    _cache.put(key, content);

    // 写入磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(content);

    debugPrint('缓存已写入：$key');
  }

  /// 移除章节缓存
  Future<void> remove(int bookId, int chapterId) async {
    final key = _getCacheKey(bookId, chapterId);
    _cache.remove(key);

    final cacheFile = File(p.join(_cacheDir.path, '$key.txt'));
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
  }

  /// 清除书籍的所有缓�?
  Future<void> clearBook(int bookId) async {
    final keysToRemove = <String>[];
    final prefix = 'book_${bookId}_';

    // 收集要删除的�?
    for (final key in _cache._cache.keys) {
      if (key.toString().startsWith(prefix)) {
        keysToRemove.add(key.toString());
      }
    }

    // 从内存缓存删�?
    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    // 从磁盘缓存删�?
    if (await _cacheDir.exists()) {
      await for (final entity in _cacheDir.list()) {
        if (entity is File && p.basename(entity.path).startsWith(prefix)) {
          await entity.delete();
        }
      }
    }

    debugPrint('书籍缓存已清除：bookId=$bookId');
  }

  /// 清除所有缓�?
  Future<void> clearAll() async {
    _cache.clear();

    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create(recursive: true);
    }

    debugPrint('所有缓存已清除');
  }

  /// 获取缓存统计
  CacheStats getStats() {
    return CacheStats(
      memoryCacheSize: _cache.length,
      memoryCacheTotalSize: _cache.totalSize,
      diskCachePath: _cacheDir.path,
    );
  }
}

/// 图片缓存
class ImageCache {
  static ImageCache? _instance;
  late final LruCache<String, ui.Image> _memoryCache;
  late final Directory _cacheDir;
  final int _maxMemorySize;
  final int _maxDiskSize;

  ImageCache._({int maxMemorySize = 50, int maxDiskSize = 100})
    : _maxMemorySize = maxMemorySize,
      _maxDiskSize = maxDiskSize {
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

  /// 获取缓存�?
  String _getCacheKey(String imagePath) => imagePath.hashCode.toString();

  /// 获取图片
  Future<ui.Image?> get(String imagePath) async {
    final key = _getCacheKey(imagePath);

    // 先尝试内存缓�?
    final cached = _memoryCache.get(key);
    if (cached != null) {
      debugPrint('图片内存缓存命中�?imagePath');
      return cached;
    }

    // 尝试磁盘缓存
    final cacheFile = File(p.join(_cacheDir.path, '$key.png'));
    if (await cacheFile.exists()) {
      debugPrint('图片磁盘缓存命中�?imagePath');
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
    final byteData = await image.toByteData();
    if (byteData != null) {
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    debugPrint('图片缓存已写入：$imagePath');
  }

  /// 清除所有缓�?
  Future<void> clearAll() async {
    _memoryCache.clear();

    if (await _cacheDir.exists()) {
      await _cacheDir.delete(recursive: true);
      await _cacheDir.create(recursive: true);
    }

    debugPrint('图片缓存已清�?');
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
  final ChapterContentCache _contentCache;
  final List<int> _prefetchQueue;
  bool _isPrefetching = false;

  PrefetchManager(this._contentCache) : _prefetchQueue = [];

  /// 添加预加载任�?
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
      debugPrint('预加载章节：$chapterId');
    }

    _isPrefetching = false;
  }

  /// 取消所有预加载任务
  void cancelAll() {
    _prefetchQueue.clear();
    _isPrefetching = false;
  }
}
