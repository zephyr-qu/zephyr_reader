/// 阅读会话领域模型
library;


import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'reading_session.freezed.dart';

/// 阅读会话领域模型
@freezed
abstract class ReadingSession with _$ReadingSession {
  const factory ReadingSession({
    /// 会话 ID（UUID）
    required int id,

    /// 书籍 ID
    required int bookId,

    /// 章节 ID
    required int chapterId,

    /// 开始时间戳（Unix 时间戳，秒）
    required int startTimestamp,

    /// 结束时间戳（Unix 时间戳，秒）
    required int endTimestamp,

    /// 阅读时长（秒）
    required int durationSeconds,

    /// 阅读字数
    @Default(0) int charactersRead,
  }) = _ReadingSession;

  /// 从数据库模型转换
  factory ReadingSession.fromDb(DbReadingSession db) {
    return ReadingSession(
      id: db.id,
      bookId: db.bookId,
      chapterId: db.chapterId,
      startTimestamp: db.startTimestamp,
      endTimestamp: db.endTimestamp,
      durationSeconds: db.durationSeconds,
      charactersRead: db.charactersRead,
    );
  }

  /// 空会话
  factory ReadingSession.empty() {
    return ReadingSession(
      id: 0,
      bookId: 0,
      chapterId: 0,
      startTimestamp: 0,
      endTimestamp: 0,
      durationSeconds: 0,
    );
  }
}

