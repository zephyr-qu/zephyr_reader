/// 书签统一领域模型
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';

/// 书签领域模型
@freezed
class BookmarkItem with _$BookmarkItem {
  const factory BookmarkItem({
    /// 书签唯一标识（UUID）
    required String id,

    /// 关联的书籍 ID
    required String bookId,

    /// 关联的章节 ID
    required int chapterId,

    /// 书签位置（字符偏移量或页码）
    required int position,

    /// 书签备注
    String? note,

    /// 创建时间
    required DateTime createdAt,
  }) = _BookmarkItem;

  /// 从数据库模型转换
  factory BookmarkItem.fromDb(dynamic dbBookmark) {
    return BookmarkItem(
      id: dbBookmark.id.toString(),
      bookId: dbBookmark.bookId.toString(),
      chapterId: dbBookmark.chapterId,
      position: dbBookmark.position,
      note: dbBookmark.note,
      createdAt: dbBookmark.createdAt,
    );
  }

  /// 从 Rust Bookmark 转换
  factory BookmarkItem.fromRust(dynamic rustBookmark) {
    return BookmarkItem(
      id: rustBookmark.bookmarkId,
      bookId: rustBookmark.bookId,
      chapterId: rustBookmark.chapterId,
      position: rustBookmark.pageIndex,
      note: rustBookmark.note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (rustBookmark.createdTimestamp * 1000).toInt(),
      ),
    );
  }

  /// 空书签（用于初始化）
  factory BookmarkItem.empty() {
    return BookmarkItem(
      id: '',
      bookId: '',
      chapterId: 0,
      position: 0,
      createdAt: DateTime.now(),
    );
  }
}
