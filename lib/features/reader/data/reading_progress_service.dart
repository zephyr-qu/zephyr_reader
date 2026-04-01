/// 阅读进度服务（基于 Drift）
///
/// 功能：
/// - 保存和加载阅读进度
/// - 记录阅读时长
/// - 所有数据持久化到 Flutter 侧的 Drift 数据库
library;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/reading_progress.dart';

/// 阅读进度数据
class ReadingProgressData {
  final int bookId;
  final int chapterId;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;

  ReadingProgressData({
    required this.bookId,
    required this.chapterId,
    required this.pageIndex,
    required this.totalPages,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });

  /// 获取进度百分比
  double get progressPercent =>
      totalPages > 0 ? (pageIndex + 1) / totalPages : 0.0;

  /// 格式化进度文本
  String get progressText => '${(progressPercent * 100).toStringAsFixed(1)}%';

  /// 格式化时间文本
  String get readingTimeText {
    final minutes = readingTimeSeconds ~/ 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      return '$hours小时${minutes % 60}分钟';
    } else if (minutes > 0) {
      return '$minutes分钟${readingTimeSeconds % 60}秒';
    } else {
      return '$readingTimeSeconds秒';
    }
  }
}

/// 阅读进度服务
@injectable
class ReadingProgressService {
  final AppDatabase _db;

  /// 内存缓存：bookId -> ReadingProgressData
  ReadingProgressData? _currentProgress;

  ReadingProgressService(this._db);

  /// 更新阅读进度
  Future<void> updateReadingProgress({
    required int bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    try {
      await _db.updateReadingProgress(
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        totalPages: totalPages,
        readingTimeSeconds: readingTimeSeconds,
      );

      // 更新缓存
      _currentProgress = ReadingProgressData(
        bookId: bookId,
        chapterId: chapterId,
        pageIndex: pageIndex,
        totalPages: totalPages,
        readingTimeSeconds: readingTimeSeconds,
        lastReadAt: DateTime.now(),
      );

      debugPrint(
        '保存进度：book=$bookId, chapter=$chapterId, page=$pageIndex/$totalPages, time=${readingTimeSeconds}s',
      );
    } catch (e) {
      debugPrint('ReadingProgressService.updateReadingProgress error: $e');
      rethrow;
    }
  }

  /// 加载阅读进度
  Future<ReadingProgressData?> loadReadingProgress(int bookId) async {
    try {
      // 先检查缓存
      if (_currentProgress != null &&
          _currentProgress!.bookId == bookId) {
        return _currentProgress;
      }

      final readingProgress = await _db.getReadingProgress(bookId);
      if (readingProgress == null) {
        return null;
      }

      final progress = ReadingProgress.fromDb(readingProgress);
      _currentProgress = ReadingProgressData(
        bookId: bookId,
        chapterId: progress.chapterId,
        pageIndex: progress.pageIndex,
        totalPages: progress.totalPages,
        readingTimeSeconds: progress.readingTimeSeconds,
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(
          progress.lastReadTimestamp * 1000,
        ),
      );

      return _currentProgress;
    } catch (e) {
      debugPrint('ReadingProgressService.loadReadingProgress error: $e');
      return null;
    }
  }

  /// 获取当前缓存的进度
  ReadingProgressData? get currentProgress => _currentProgress;

  /// 清除阅读进度
  Future<void> clearReadingProgress(int bookId) async {
    try {
      await _db.clearReadingProgress(bookId);
      if (_currentProgress?.bookId == bookId) {
        _currentProgress = null;
      }
    } catch (e) {
      debugPrint('ReadingProgressService.clearReadingProgress error: $e');
    }
  }

  /// 获取所有阅读进度
  Future<List<ReadingProgressData>> getAllReadingProgress() async {
    try {
      final progressList = await _db.getAllReadingProgress();
      return progressList
          .map((progress) {
            final dbProgress = ReadingProgress.fromDb(progress);
            return ReadingProgressData(
              bookId: dbProgress.bookId,
              chapterId: dbProgress.chapterId,
              pageIndex: dbProgress.pageIndex,
              totalPages: dbProgress.totalPages,
              readingTimeSeconds: dbProgress.readingTimeSeconds,
              lastReadAt: DateTime.fromMillisecondsSinceEpoch(
                progress.lastReadTimestamp * 1000,
              ),
            );
          })
          .toList();
    } catch (e) {
      debugPrint('ReadingProgressService.getAllReadingProgress error: $e');
      return [];
    }
  }

  /// 清除所有缓存
  void clearCache() {
    _currentProgress = null;
  }
}
