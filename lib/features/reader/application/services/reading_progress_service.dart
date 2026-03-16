/// 阅读进度服务（基于 Drift）
///
/// 功能：
/// - 保存和加载阅读进度
/// - 记录阅读时长
/// - 所有数据持久化到 Flutter 侧的 Drift 数据库
library;

import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/database/tables/reading_progress.dart';

/// 阅读进度服务
class ReadingProgressService {
  final AppDatabase _db;

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
        bookId: bookId.toString(),
        chapterId: chapterId,
        pageIndex: pageIndex,
        totalPages: totalPages,
        readingTimeSeconds: readingTimeSeconds,
      );
      debugPrint(
        '保存进度：book=$bookId, chapter=$chapterId, page=$pageIndex/$totalPages',
      );
    } catch (e) {
      debugPrint('ReadingProgressService.updateReadingProgress error: $e');
      rethrow;
    }
  }

  /// 加载阅读进度
  Future<ReadingProgressItem?> loadReadingProgress(int bookId) async {
    try {
      return await _db.getReadingProgress(bookId.toString());
    } catch (e) {
      debugPrint('ReadingProgressService.loadReadingProgress error: $e');
      return null;
    }
  }

  /// 清除阅读进度
  Future<void> clearReadingProgress(int bookId) async {
    try {
      await _db.clearReadingProgress(bookId.toString());
    } catch (e) {
      debugPrint('ReadingProgressService.clearReadingProgress error: $e');
    }
  }

  /// 获取所有阅读进度
  Future<List<ReadingProgressItem>> getAllReadingProgress() async {
    try {
      return await _db.getAllReadingProgress();
    } catch (e) {
      debugPrint('ReadingProgressService.getAllReadingProgress error: $e');
      return [];
    }
  }
}
