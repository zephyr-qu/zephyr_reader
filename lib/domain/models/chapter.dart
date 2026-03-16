/// 章节统一领域模型
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chapter.freezed.dart';

/// 章节领域模型
@freezed
abstract class Chapter with _$Chapter {
  const factory Chapter({
    /// 章节唯一标识
    required int id,

    /// 关联的书籍 ID
    required String bookId,

    /// 章节标题
    required String title,

    /// 章节内容文件路径
    required String contentFile,

    /// 章节索引（从 1 开始）
    required int chapterIndex,

    /// 字数
    required int wordCount,

    /// 缓存时间
    DateTime? cachedAt,
  }) = _Chapter;

  /// 从数据库模型转换
  factory Chapter.fromDb(dynamic dbChapter) {
    return Chapter(
      id: dbChapter.id,
      bookId: dbChapter.bookId.toString(),
      title: dbChapter.title,
      contentFile: dbChapter.contentFile,
      chapterIndex: dbChapter.chapterIndex,
      wordCount: dbChapter.wordCount,
      cachedAt: dbChapter.cachedAt,
    );
  }

  /// 从 Rust ChapterInfo 转换
  factory Chapter.fromRust(dynamic rustChapterInfo, String bookId) {
    return Chapter(
      id: rustChapterInfo.chapterId,
      bookId: bookId,
      title: rustChapterInfo.title,
      contentFile: '',
      chapterIndex: rustChapterInfo.index,
      wordCount: rustChapterInfo.contentLength.toInt(),
    );
  }

  /// 空章节（用于初始化）
  factory Chapter.empty() {
    return Chapter(
      id: 0,
      bookId: '',
      title: '',
      contentFile: '',
      chapterIndex: 0,
      wordCount: 0,
    );
  }
}
