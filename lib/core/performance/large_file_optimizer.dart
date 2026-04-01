/// 大文件加载优化器
///
/// 优化大文件（>10MB）的加载性能，支持分块加载、预加载和内存管理
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/logging.dart';

/// 大文件加载优化器
class LargeFileOptimizer {
  /// 大文件阈值（10MB）
  static const int largeFileThreshold = 10 * 1024 * 1024;

  /// 分块大小（1MB）
  static const int chunkSize = 1024 * 1024;

  /// 预加载块数
  static const int preloadChunks = 3;

  /// 最大缓存块数（防止内存溢出）
  static const int maxCachedChunks = 10;

  /// 已加载的块缓存（LRU 缓存）
  static final _chunkCache = <String, _CachedChunk>{};

  /// 预加载任务队列
  static final _preloadQueue = Queue<_PreloadTask>();

  /// 预加载是否正在进行
  static bool _isPreloading = false;

  /// 分块加载文件
  ///
  /// [filePath] 文件路径
  /// [chunkSize] 分块大小（字节）
  /// [onProgress] 进度回调（已加载块数，总块数）
  ///
  /// 返回加载的文本块列表
  static Future<List<String>> loadFileInChunks(
    String filePath, {
    int chunkSize = LargeFileOptimizer.chunkSize,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在：$filePath');
    }

    final fileSize = await file.length();
    final isLargeFile = fileSize > largeFileThreshold;

    if (isLargeFile) {
      Logging.debug('大文件检测：${fileSize ~/ 1024 ~/ 1024}MB，使用分块加载');
      return _loadLargeFile(file, chunkSize, onProgress);
    } else {
      // 小文件直接加载
      final content = await file.readAsString();
      onProgress?.call(1, 1);
      return [content];
    }
  }

  /// 加载大文件
  static Future<List<String>> _loadLargeFile(
    File file,
    int chunkSize,
    void Function(int, int)? onProgress,
  ) async {
    final chunks = <String>[];
    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();

    final randomAccessFile = await file.open();
    try {
      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = ((i + 1) * chunkSize).clamp(0, fileSize);

        await randomAccessFile.setPosition(start);
        final bytes = await randomAccessFile.read(end - start);
        chunks.add(String.fromCharCodes(bytes));

        onProgress?.call(i + 1, totalChunks);

        // 让出事件循环，避免阻塞 UI
        if (i % 10 == 0) {
          await Future.delayed(Duration.zero);
        }
      }
    } finally {
      await randomAccessFile.close();
    }

    return chunks;
  }

  /// 预加载后续块
  ///
  /// [filePath] 文件路径
  /// [currentChunkIndex] 当前块索引
  /// [chunksToPreload] 要预加载的块数
  ///
  /// 将后续块异步加载到缓存中
  static Future<void> preloadNextChunks(
    String filePath,
    int currentChunkIndex,
    int chunksToPreload,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) {
      Logging.warning('文件不存在，跳过预加载：$filePath');
      return;
    }

    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();

    // 计算要预加载的块索引
    final startChunk = currentChunkIndex + 1;
    final endChunk = (startChunk + chunksToPreload).clamp(0, totalChunks);

    if (startChunk >= totalChunks) {
      Logging.debug('已到文件末尾，无需预加载');
      return;
    }

    // 添加预加载任务到队列
    for (int i = startChunk; i < endChunk; i++) {
      final cacheKey = '$filePath:$i';

      // 如果已缓存则跳过
      if (_chunkCache.containsKey(cacheKey)) {
        continue;
      }

      _preloadQueue.add(
        _PreloadTask(filePath: filePath, chunkIndex: i, cacheKey: cacheKey),
      );
    }

    Logging.debug('预加载任务已添加：$startChunk - $endChunk');

    // 触发预加载
    if (!_isPreloading) {
      _processPreloadQueue(file).ignore();
    }
  }

  /// 处理预加载队列
  static Future<void> _processPreloadQueue(File file) async {
    if (_isPreloading || _preloadQueue.isEmpty) {
      return;
    }

    _isPreloading = true;

    try {
      final randomAccessFile = await file.open();
      try {
        while (_preloadQueue.isNotEmpty) {
          final task = _preloadQueue.removeFirst();
          final cacheKey = task.cacheKey;

          // 再次检查是否已缓存（避免重复加载）
          if (_chunkCache.containsKey(cacheKey)) {
            continue;
          }

          try {
            final start = task.chunkIndex * chunkSize;
            final end = ((task.chunkIndex + 1) * chunkSize).clamp(
              0,
              await file.length(),
            );

            await randomAccessFile.setPosition(start);
            final bytes = await randomAccessFile.read(end - start);
            final content = String.fromCharCodes(bytes);

            // 添加到缓存
            _chunkCache[cacheKey] = _CachedChunk(
              content: content,
              loadedAt: DateTime.now(),
              chunkIndex: task.chunkIndex,
            );

            // 如果缓存超出限制，清理最旧的块
            if (_chunkCache.length > maxCachedChunks) {
              _evictOldestChunk();
            }

            Logging.debug('预加载完成：${task.filePath} 块 ${task.chunkIndex}');
          } catch (e) {
            Logging.warning(
              '预加载失败：${task.filePath} 块 ${task.chunkIndex}, 错误：$e',
            );
          }

          // 让出事件循环
          await Future.delayed(Duration.zero);
        }
      } finally {
        await randomAccessFile.close();
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// 清理最旧的缓存块
  static void _evictOldestChunk() {
    if (_chunkCache.isEmpty) {
      return;
    }

    // 找到最旧的块
    _CachedChunk? oldest;
    String? oldestKey;

    for (final entry in _chunkCache.entries) {
      if (oldest == null || entry.value.loadedAt.isBefore(oldest.loadedAt)) {
        oldest = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _chunkCache.remove(oldestKey);
      Logging.debug('清理缓存块：$oldestKey');
    }
  }

  /// 释放已加载的块
  ///
  /// [chunks] 块列表
  /// [keepFrom] 保留的起始索引（包含）
  /// [keepTo] 保留的结束索引（不包含）
  ///
  /// 释放范围外的块以节省内存
  static void releaseChunks(List<String> chunks, int keepFrom, int keepTo) {
    if (chunks.isEmpty) {
      return;
    }

    // 确保范围有效
    final from = keepFrom.clamp(0, chunks.length);
    final to = keepTo.clamp(0, chunks.length);

    if (from >= to) {
      debugPrint('无效范围，释放所有块：$from - $to');
      chunks.clear();
      return;
    }

    // 计算需要释放的块
    final chunksToRemove = <int>[];

    // 释放起始索引之前的块
    for (int i = 0; i < from; i++) {
      chunksToRemove.add(i);
    }

    // 释放结束索引之后的块
    for (int i = to; i < chunks.length; i++) {
      chunksToRemove.add(i);
    }

    // 释放块（从后向前，避免索引偏移）
    for (final index in chunksToRemove.reversed) {
      if (index >= 0 && index < chunks.length) {
        chunks[index] = ''; // 清空内容而不是直接移除，保持索引稳定
      }
    }

    // 触发 GC 提示
    Logging.debug('释放块完成：保留 $from - $to，已清空 ${chunksToRemove.length} 个块');
  }

  /// 从缓存获取块
  ///
  /// [filePath] 文件路径
  /// [chunkIndex] 块索引
  ///
  /// 返回缓存的块内容，如果不存在则返回 null
  static String? getCachedChunk(String filePath, int chunkIndex) {
    final cacheKey = '$filePath:$chunkIndex';
    return _chunkCache[cacheKey]?.content;
  }

  /// 清除所有缓存
  ///
  /// 清理所有预加载和缓存的块
  static void clearCache() {
    _chunkCache.clear();
    _preloadQueue.clear();
    Logging.debug('已清除所有缓存');
  }

  /// 获取缓存统计信息
  ///
  /// 返回缓存的块数和内存占用估算
  static ChunkCacheStats getCacheStats() {
    final totalSize = _chunkCache.values.fold<int>(
      0,
      (sum, chunk) => sum + chunk.content.length,
    );

    return ChunkCacheStats(
      cachedChunks: _chunkCache.length,
      estimatedMemoryBytes: totalSize,
      preloadQueueLength: _preloadQueue.length,
    );
  }

  /// 获取文件加载策略
  static FileLoadingStrategy getLoadingStrategy(int fileSize) {
    if (fileSize < 1024 * 1024) {
      return FileLoadingStrategy.direct;
    } else if (fileSize < 10 * 1024 * 1024) {
      return FileLoadingStrategy.buffered;
    } else {
      return FileLoadingStrategy.chunked;
    }
  }
}

/// 缓存的块
class _CachedChunk {
  final String content;
  final DateTime loadedAt;
  final int chunkIndex;

  _CachedChunk({
    required this.content,
    required this.loadedAt,
    required this.chunkIndex,
  });
}

/// 预加载任务
class _PreloadTask {
  final String filePath;
  final int chunkIndex;
  final String cacheKey;

  _PreloadTask({
    required this.filePath,
    required this.chunkIndex,
    required this.cacheKey,
  });
}

/// 文件加载策略
enum FileLoadingStrategy {
  /// 直接加载 <1MB
  direct,

  /// 缓冲加载 1-10MB
  buffered,

  /// 分块加载 >10MB
  chunked,
}

/// 缓存统计信息
class ChunkCacheStats {
  /// 已缓存的块数
  final int cachedChunks;

  /// 估算的内存占用（字节）
  final int estimatedMemoryBytes;

  /// 预加载队列长度
  final int preloadQueueLength;

  ChunkCacheStats({
    required this.cachedChunks,
    required this.estimatedMemoryBytes,
    required this.preloadQueueLength,
  });

  @override
  String toString() {
    return 'ChunkCacheStats(cached: $cachedChunks, memory: ${estimatedMemoryBytes ~/ 1024}KB, queue: $preloadQueueLength)';
  }
}

/// 文件加载器（优化版）
class OptimizedFileLoader {
  final String filePath;
  final FileLoadingStrategy strategy;
  final int fileSize;

  OptimizedFileLoader._(this.filePath, this.strategy, this.fileSize);

  /// 创建优化的文件加载器
  static Future<OptimizedFileLoader> create(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('文件不存在：$filePath');
    }

    final fileSize = await file.length();
    final strategy = LargeFileOptimizer.getLoadingStrategy(fileSize);

    return OptimizedFileLoader._(filePath, strategy, fileSize);
  }

  /// 加载文件内容
  Future<String> load() async {
    switch (strategy) {
      case FileLoadingStrategy.direct:
        return File(filePath).readAsString();

      case FileLoadingStrategy.buffered:
        return _loadBuffered();

      case FileLoadingStrategy.chunked:
        final chunks = await LargeFileOptimizer.loadFileInChunks(filePath);
        return chunks.join();
    }
  }

  /// 缓冲加载
  Future<String> _loadBuffered() async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // 使用 UTF-8 解码
    String content;
    try {
      content = String.fromCharCodes(bytes);
    } catch (e) {
      // 尝试其他编码
      content = await file.readAsString();
    }

    return content;
  }
}
