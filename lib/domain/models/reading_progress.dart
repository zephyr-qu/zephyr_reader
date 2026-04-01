/// 阅读进度统一领域模型
///
/// 与数据库模型 DbReadingProgress 对齐
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'reading_progress.freezed.dart';

/// 阅读进度领域模型
@freezed
abstract class ReadingProgress with _$ReadingProgress {
  const factory ReadingProgress({
    /// 书籍 ID
    required int bookId,

    /// 当前章节 ID
    required int chapterId,

    /// 当前页码
    required int pageIndex,

    /// 总页数
    required int totalPages,

    /// 进度百分比（0.0 - 1.0）
    @Default(0.0) double progress,

    /// 已阅读时间（秒）
    @Default(0) int readingTimeSeconds,

    /// 最后阅读时间戳（Unix 时间戳，秒）
    required int lastReadTimestamp,
  }) = _ReadingProgress;

  /// 从数据库模型转换
  factory ReadingProgress.fromDb(DbReadingProgress dbReadingProgress) {
    return ReadingProgress(
      bookId: dbReadingProgress.bookId,
      chapterId: dbReadingProgress.chapterId,
      pageIndex: dbReadingProgress.pageIndex,
      totalPages: dbReadingProgress.totalPages,
      progress: dbReadingProgress.progress,
      readingTimeSeconds: dbReadingProgress.readingTimeSeconds,
      lastReadTimestamp: dbReadingProgress.lastReadTimestamp,
    );
  }

  /// 空阅读进度（用于初始化）
  factory ReadingProgress.empty() {
    return const ReadingProgress(
      bookId: 0,
      chapterId: 0,
      pageIndex: 0,
      totalPages: 0,
      progress: 0.0,
      readingTimeSeconds: 0,
      lastReadTimestamp: 0,
    );
  }
}
