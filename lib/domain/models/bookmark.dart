/// 书签统一领域模型
library;


import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';

/// 书签领域模型
@freezed
abstract class Bookmark with _$Bookmark {
  const factory Bookmark({
    /// 书签唯一标识（UUID）
    required int id,

    /// 关联的书籍 ID
    required int bookId,

    /// 关联的章节 ID
    required int chapterId,

    /// 书签位置（字符偏移量或页码）
    required int position,

    /// 书签备注
    String? note,

    /// 创建时间
    required DateTime createdAt,
  }) = _Bookmark;

  /// 从数据库模型转换
  factory Bookmark.fromDb(dynamic dbBookmark) {
    return Bookmark(
      id: dbBookmark.id,
      bookId: dbBookmark.bookId,
      chapterId: dbBookmark.chapterId,
      position: dbBookmark.position,
      note: dbBookmark.note,
      createdAt: dbBookmark.createdAt,
    );
  }

  /// 空书签（用于初始化）
  factory Bookmark.empty() {
    return Bookmark(
      id: 0,
      bookId: 0,
      chapterId: 0,
      position: 0,
      createdAt: DateTime.now(),
    );
  }
}


