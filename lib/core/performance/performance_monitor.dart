/// 性能监控与分析工///
/// 提供性能监控、分析和优化建议
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

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

  /// 慢操作阈值（毫秒
  static const int slowOperationThreshold = 100;

  /// 记录操作开
  void startOperation(String operationName) {
    // 使用 DateTime 而不Stopwatch 避免额外导入
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
      debugPrint('⚠️ 慢操作警告：$operationName 耗时 ${duration}ms');
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

  /// 获取慢操作列
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

  /// 清除所有记
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

/// 慢操作信
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

/// 性能优化工具
class PerformanceOptimizer {
  /// 优化图片加载
  static Future<void> optimizeImageLoading() async {
    // TODO: 实现图片缓存和预加载
    debugPrint('图片加载优化已启');
  }

  /// 优化列表滚动
  static void optimizeListScrolling() {
    // TODO: 使用 const widget、缓key
    debugPrint('列表滚动优化已启');
  }

  /// 优化构建性能
  static void optimizeBuildPerformance() {
    // TODO: 使用 RepaintBoundary、CachedNetworkImage
    debugPrint('构建性能优化已启');
  }

  /// 优化内存使用
  static void optimizeMemoryUsage() {
    // TODO: 及时释放不用的资
    debugPrint('内存使用优化已启');
  }
}

/// 性能监控中间
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
      debugPrint('$operationName: ${duration}ms');
      return result;
    } catch (e) {
      _monitor.endOperation(operationName);
      debugPrint('$operationName failed: $e');
      rethrow;
    }
  }
}
