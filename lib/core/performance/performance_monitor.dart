/// 性能监控与分析工具
///
/// 提供性能监控、分析和优化建议
library;

import 'dart:async';
import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/logging.dart';

/// 性能监控
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  /// 操作耗时记录
  final _operationTimes = HashMap<String, List<int>>();

  /// 内存使用记录
  final _memoryUsage = <int>[];

  /// 帧率记录
  final _frameRates = <double>[];

  /// 慢操作阈值（毫秒）
  static const int slowOperationThreshold = 100;

  /// 记录操作开始
  void startOperation(String operationName) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    _operationTimes.putIfAbsent(operationName, () => []).add(startTime);
  }

  /// 记录操作结束并返回耗时
  int endOperation(String operationName) {
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final startTimes = _operationTimes[operationName];

    if (startTimes == null || startTimes.isEmpty) {
      return 0;
    }

    final startTime = startTimes.removeLast();
    final duration = endTime - startTime;

    if (duration > slowOperationThreshold) {
      Logging.warning('⚠️ 慢操作警告：$operationName 耗时 ${duration}ms');
    }

    return duration;
  }

  /// 记录内存使用
  void recordMemoryUsage(int bytes) {
    _memoryUsage.add(bytes);
    if (_memoryUsage.length > 100) {
      _memoryUsage.removeAt(0);
    }
  }

  /// 记录帧率
  void recordFrameRate(double fps) {
    _frameRates.add(fps);
    if (_frameRates.length > 100) {
      _frameRates.removeAt(0);
    }
  }

  /// 获取平均操作耗时
  int getAverageOperationTime(String operationName) {
    final times = _operationTimes[operationName];
    if (times == null || times.isEmpty) {
      return 0;
    }
    return times.reduce((a, b) => a + b) ~/ times.length;
  }

  /// 获取平均内存使用
  int getAverageMemoryUsage() {
    if (_memoryUsage.isEmpty) {
      return 0;
    }
    return _memoryUsage.reduce((a, b) => a + b) ~/ _memoryUsage.length;
  }

  /// 获取平均帧率
  double getAverageFrameRate() {
    if (_frameRates.isEmpty) {
      return 0.0;
    }
    return _frameRates.reduce((a, b) => a + b) / _frameRates.length;
  }

  /// 获取性能报告
  PerformanceReport getReport() {
    return PerformanceReport(
      operationTimes: Map.unmodifiable(_operationTimes),
      averageMemoryUsage: getAverageMemoryUsage(),
      averageFrameRate: getAverageFrameRate(),
      slowOperations: _getSlowOperations(),
    );
  }

  /// 获取慢操作列表
  List<SlowOperation> _getSlowOperations() {
    final slowOps = <SlowOperation>[];

    for (final entry in _operationTimes.entries) {
      final avgTime = entry.value.reduce((a, b) => a + b) ~/ entry.value.length;
      if (avgTime > slowOperationThreshold) {
        slowOps.add(
          SlowOperation(
            name: entry.key,
            averageTime: avgTime,
            maxTime: entry.value.reduce((a, b) => a > b ? a : b),
            count: entry.value.length,
          ),
        );
      }
    }

    slowOps.sort((a, b) => b.averageTime.compareTo(a.averageTime));
    return slowOps;
  }

  /// 清除所有记录
  void clear() {
    _operationTimes.clear();
    _memoryUsage.clear();
    _frameRates.clear();
  }
}

/// 性能报告
class PerformanceReport {
  final Map<String, List<int>> operationTimes;
  final int averageMemoryUsage;
  final double averageFrameRate;
  final List<SlowOperation> slowOperations;

  PerformanceReport({
    required this.operationTimes,
    required this.averageMemoryUsage,
    required this.averageFrameRate,
    required this.slowOperations,
  });

  @override
  String toString() {
    return 'PerformanceReport('
        'avgMemory: ${averageMemoryUsage ~/ 1024}KB, '
        'avgFPS: ${averageFrameRate.toStringAsFixed(1)}, '
        'slowOps: ${slowOperations.length})';
  }
}

/// 慢操作信息
class SlowOperation {
  final String name;
  final int averageTime;
  final int maxTime;
  final int count;

  SlowOperation({
    required this.name,
    required this.averageTime,
    required this.maxTime,
    required this.count,
  });

  @override
  String toString() {
    return 'SlowOperation($name: avg=${averageTime}ms, max=${maxTime}ms, count=$count)';
  }
}

/// 图片预加载任务
class _ImagePreloadTask {
  final String imageUrl;
  final DateTime createdAt;

  _ImagePreloadTask(this.imageUrl, this.createdAt);
}

/// 性能优化工具
class PerformanceOptimizer {
  /// 图片预加载队列
  static final _imagePreloadQueue = ListQueue<_ImagePreloadTask>();

  /// 已预加载的图片缓存
  static final _preloadedImages = HashSet<String>();

  /// 最大预加载图片数
  static const int _maxPreloadImages = 20;

  /// 预加载是否正在进行
  static bool _isPreloading = false;

  /// 优化图片加载
  ///
  /// 初始化图片缓存配置
  static Future<void> optimizeImageLoading() async {
    // 使用 ImageCache 管理缓存
    // cached_network_image 会自动使用 Flutter 的 ImageCache
    // 可以通过 PaintingBinding.instance.imageCache 配置缓存大小
    PaintingBinding.instance.imageCache.maximumSize = 100; // 最多缓存 100 张图片
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        100 * 1024 * 1024; // 100MB

    debugPrint('图片加载优化已启用，缓存配置完成');
  }

  /// 预加载单张图片
  ///
  /// [imageUrl] 图片 URL
  /// [maxWidth] 最大宽度（可选，用于限制缓存大小）
  /// [maxHeight] 最大高度（可选，用于限制缓存大小）
  static Future<void> preloadImage(
    String imageUrl, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (_preloadedImages.contains(imageUrl)) {
      return;
    }

    if (_imagePreloadQueue.length >= _maxPreloadImages) {
      _imagePreloadQueue.removeFirst();
    }

    _imagePreloadQueue.add(_ImagePreloadTask(imageUrl, DateTime.now()));

    // 触发预加载
    if (!_isPreloading) {
      _processPreloadQueue(maxWidth: maxWidth, maxHeight: maxHeight).ignore();
    }
  }

  /// 批量预加载图片
  ///
  /// [imageUrls] 图片 URL 列表
  static Future<void> preloadImages(
    List<String> imageUrls, {
    int? maxWidth,
    int? maxHeight,
  }) async {
    for (final url in imageUrls) {
      await preloadImage(url, maxWidth: maxWidth, maxHeight: maxHeight);
    }
  }

  /// 处理预加载队列
  static Future<void> _processPreloadQueue({
    int? maxWidth,
    int? maxHeight,
  }) async {
    if (_isPreloading || _imagePreloadQueue.isEmpty) {
      return;
    }

    _isPreloading = true;

    try {
      while (_imagePreloadQueue.isNotEmpty) {
        final task = _imagePreloadQueue.removeFirst();

        if (_preloadedImages.contains(task.imageUrl)) {
          continue;
        }

        // 使用 precacheImage 预加载图片到缓存
        final completer = Completer<void>();
        final imageProvider = CachedNetworkImageProvider(
          task.imageUrl,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        );

        // 创建一个假的 BuildContext 用于 precacheImage
        // 注意：这里使用一个简单的方式，直接加载图片到缓存
        final imageStream = imageProvider.resolve(
          const ImageConfiguration(size: Size(400, 400), devicePixelRatio: 1),
        );

        ImageStreamListener? listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool syncCall) {
            if (!completer.isCompleted) {
              completer.complete();
            }
            imageStream.removeListener(listener!);
          },
          onError: (Object exception, StackTrace? stackTrace) {
            if (!completer.isCompleted) {
              debugPrint('图片预加载失败：${task.imageUrl}, 错误：$exception');
              completer.completeError(exception);
            }
            imageStream.removeListener(listener!);
          },
        );

        imageStream.addListener(listener);

        try {
          await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () => Logging.warning('图片预加载超时：${task.imageUrl}'),
          );
        } finally {
          imageStream.removeListener(listener);
        }

        _preloadedImages.add(task.imageUrl);
        Logging.debug('图片预加载完成：${task.imageUrl}');
      }
    } finally {
      _isPreloading = false;
    }
  }

  /// 清除预加载队列
  static void clearPreloadQueue() {
    _imagePreloadQueue.clear();
    _preloadedImages.clear();
    Logging.debug('预加载队列已清除');
  }

  /// 从预加载缓存中移除图片
  static Future<void> removePreloadedImage(String imageUrl) async {
    _preloadedImages.remove(imageUrl);
    final provider = CachedNetworkImageProvider(imageUrl);
    await provider.evict();
    Logging.debug('图片已从预加载缓存移除：$imageUrl');
  }

  /// 优化列表滚动
  ///
  /// 返回一个优化后的 ListView.builder 配置
  static ListViewBuilderOptimization optimizeListScrolling() {
    return ListViewBuilderOptimization();
  }

  /// 优化构建性能
  ///
  /// 返回一个构建性能优化工具
  static BuildPerformanceOptimizer optimizeBuildPerformance() {
    return BuildPerformanceOptimizer();
  }

  /// 优化内存使用
  ///
  /// 执行内存清理操作
  static Future<void> optimizeMemoryUsage() async {
    // 清理图片缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    _preloadedImages.clear();
    _imagePreloadQueue.clear();

    Logging.debug('内存使用优化完成，缓存已清理');
  }

  /// 清理所有缓存
  ///
  /// 清理图片缓存和其他缓存数据
  static Future<void> clearCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    _preloadedImages.clear();
    _imagePreloadQueue.clear();

    Logging.debug('所有缓存已清理');
  }

  /// 获取缓存统计信息
  static CacheStats getCacheStats() {
    return CacheStats(
      cachedImageCount: _preloadedImages.length,
      queueLength: _imagePreloadQueue.length,
    );
  }
}

/// ListView.builder 优化配置
class ListViewBuilderOptimization {
  /// 是否启用自动保持存活
  bool _addAutomaticKeepAlives = true;

  /// 是否添加重绘边界
  bool _addRepaintBoundaries = true;

  /// 缓存范围（像素）
  double _cacheExtent = 500;

  /// 列表项构建器
  Widget Function(BuildContext, int)? _itemBuilder;

  /// 列表项数量
  int? _itemCount;

  /// 滚动方向
  Axis _scrollDirection = Axis.vertical;

  /// 填充
  EdgeInsetsGeometry? _padding;

  /// 物理行为
  ScrollPhysics? _physics;

  /// 设置 itemBuilder
  ListViewBuilderOptimization withItemBuilder(
    Widget Function(BuildContext, int) builder,
  ) {
    _itemBuilder = builder;
    return this;
  }

  /// 设置 itemCount
  ListViewBuilderOptimization withItemCount(int count) {
    _itemCount = count;
    return this;
  }

  /// 设置 padding
  ListViewBuilderOptimization withPadding(EdgeInsetsGeometry padding) {
    _padding = padding;
    return this;
  }

  /// 设置 cacheExtent
  ListViewBuilderOptimization withCacheExtent(double extent) {
    _cacheExtent = extent;
    return this;
  }

  /// 设置 scrollDirection
  ListViewBuilderOptimization withScrollDirection(Axis direction) {
    _scrollDirection = direction;
    return this;
  }

  /// 设置自动保持存活
  ListViewBuilderOptimization withAutomaticKeepAlives(bool value) {
    _addAutomaticKeepAlives = value;
    return this;
  }

  /// 设置重绘边界
  ListViewBuilderOptimization withRepaintBoundaries(bool value) {
    _addRepaintBoundaries = value;
    return this;
  }

  /// 设置物理行为
  ListViewBuilderOptimization withPhysics(ScrollPhysics physics) {
    _physics = physics;
    return this;
  }

  /// 构建优化后的 ListView
  Widget build() {
    if (_itemBuilder == null) {
      throw StateError('必须设置 itemBuilder');
    }

    return ListView.builder(
      itemCount: _itemCount,
      itemBuilder: (context, index) => _itemBuilder!(context, index),
      scrollDirection: _scrollDirection,
      physics: _physics ?? const AlwaysScrollableScrollPhysics(),
      padding: _padding,
      addAutomaticKeepAlives: _addAutomaticKeepAlives,
      addRepaintBoundaries: _addRepaintBoundaries,
      cacheExtent: _cacheExtent,
    );
  }
}

/// 构建性能优化工具
class BuildPerformanceOptimizer {
  bool _useRepaintBoundary = true;
  bool _useCacheNetworkImage = true;

  /// 启用 RepaintBoundary
  BuildPerformanceOptimizer enableRepaintBoundary() {
    _useRepaintBoundary = true;
    return this;
  }

  /// 禁用 RepaintBoundary
  BuildPerformanceOptimizer disableRepaintBoundary() {
    _useRepaintBoundary = false;
    return this;
  }

  /// 启用 CachedNetworkImage
  BuildPerformanceOptimizer enableCacheNetworkImage() {
    _useCacheNetworkImage = true;
    return this;
  }

  /// 禁用 CachedNetworkImage
  BuildPerformanceOptimizer disableCacheNetworkImage() {
    _useCacheNetworkImage = false;
    return this;
  }

  /// 使用 RepaintBoundary 包装 widget
  Widget wrapWithRepaintBoundary(Widget child) {
    if (!_useRepaintBoundary) {
      return child;
    }
    return RepaintBoundary(child: child);
  }

  /// 创建优化的 CachedNetworkImage
  Widget createCachedNetworkImage(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    int? maxWidth,
    int? maxHeight,
  }) {
    if (!_useCacheNetworkImage) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, url, error) =>
            errorWidget ?? const Icon(Icons.error),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      imageBuilder: (context, imageProvider) =>
          Image(image: imageProvider, width: width, height: height, fit: fit),
      placeholder: (context, url) =>
          placeholder ?? const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          errorWidget ?? const Icon(Icons.error),
      cacheKey: maxWidth != null && maxHeight != null
          ? '${imageUrl}_${maxWidth}_$maxHeight'
          : null,
    );
  }

  /// 批量创建优化的 CachedNetworkImage
  List<Widget> createCachedNetworkImages(
    List<String> imageUrls, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    int? maxWidth,
    int? maxHeight,
  }) {
    return imageUrls
        .map(
          (url) => createCachedNetworkImage(
            url,
            width: width,
            height: height,
            fit: fit,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
        )
        .toList();
  }
}

/// 缓存统计信息
class CacheStats {
  /// 已缓存的图片数量
  final int cachedImageCount;

  /// 预加载队列长度
  final int queueLength;

  CacheStats({required this.cachedImageCount, required this.queueLength});

  @override
  String toString() {
    return 'CacheStats(cached: $cachedImageCount, queue: $queueLength)';
  }
}

/// 性能监控中间件
class PerformanceMiddleware {
  final PerformanceMonitor _monitor = PerformanceMonitor();

  /// 包装异步操作进行性能监控
  Future<T> trackAsync<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    _monitor.startOperation(operationName);
    try {
      final result = await operation();
      final duration = _monitor.endOperation(operationName);
      Logging.debug('$operationName: ${duration}ms');
      return result;
    } catch (e) {
      _monitor.endOperation(operationName);
      Logging.warning('$operationName failed: $e');
      rethrow;
    }
  }
}
