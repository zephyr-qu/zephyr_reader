/// 阅读历史领域模型
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'reading_history.freezed.dart';

/// 阅读历史领域模型
@freezed
abstract class ReadingHistory with _$ReadingHistory {
  const factory ReadingHistory({
    /// 自增主键
    required int id,

    /// 书籍 ID
    required int bookId,

    /// 章节 ID
    required int chapterId,

    /// 阅读位置（字符偏移量）
    required int position,

    /// 阅读时间
    required DateTime readTime,

    /// 阅读时长（秒）
    @Default(0) int duration,
  }) = _ReadingHistory;

  /// 从数据库模型转换
  factory ReadingHistory.fromDb(DbReadingHistory db) {
    return ReadingHistory(
      id: db.id,
      bookId: db.bookId,
      chapterId: db.chapterId,
      position: db.position,
      readTime: db.readTime,
      duration: db.duration,
    );
  }

  /// 空历史记录
  factory ReadingHistory.empty() {
    return ReadingHistory(
      id: 0,
      bookId: 0,
      chapterId: 0,
      position: 0,
      readTime: DateTime.now(),
    );
  }
}
