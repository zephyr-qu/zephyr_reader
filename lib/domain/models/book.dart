/// 书籍统一领域模型
///
/// 作为 Flutter 应用的核心数据模型，与 Rust 侧的 BookInfo 对齐
library;

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';

/// 书籍领域模型
@freezed
class Book with _$Book {
  const factory Book({
    /// 书籍唯一标识（与 Rust book_id 对齐，使用 UUID 字符串）
    required String id,

    /// 书籍标题
    required String title,

    /// 作者
    required String author,

    /// 封面图片路径
    String? coverPath,

    /// 描述/简介
    String? description,

    /// 本地文件路径
    required String filePath,

    /// 文件类型（txt, epub, pdf）- 与 Rust file_type 对齐
    required String fileType,

    /// 文件大小（字节）
    required int fileSize,

    /// 总章节数 - 与 Rust chapter_count 对齐
    required int chapterCount,

    /// 总字符数
    required int totalCharacters,

    /// 当前阅读章节 ID
    int? currentChapterId,

    /// 当前阅读页码
    @Default(0) int currentPageIndex,

    /// 总页数
    @Default(0) int totalPages,

    /// 阅读进度 (0.0 - 1.0)
    @Default(0.0) double progress,

    /// 阅读状态：reading-阅读中，completed-已完结，dropped-已弃坑，planned-计划阅读
    @Default('reading') String status,

    /// 是否置顶
    @Default(false) bool isPinned,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,

    /// 最后阅读时间
    DateTime? lastReadAt,
  }) = _Book;

  /// 从数据库模型转换
  factory Book.fromDb(dynamic dbBook) {
    return Book(
      id: dbBook.id.toString(),
      title: dbBook.title,
      author: dbBook.author,
      coverPath: dbBook.coverPath,
      description: dbBook.description,
      filePath: dbBook.filePath,
      fileType: dbBook.fileFormat,
      fileSize: dbBook.fileSize,
      chapterCount: dbBook.totalChapters,
      totalCharacters: dbBook.totalCharacters,
      currentChapterId: dbBook.currentChapterId,
      currentPageIndex: dbBook.currentPageIndex,
      totalPages: dbBook.totalPages,
      progress: dbBook.progress,
      status: dbBook.status,
      isPinned: dbBook.isPinned,
      createdAt: dbBook.createdAt,
      updatedAt: dbBook.updatedAt,
      lastReadAt: dbBook.lastReadAt,
    );
  }

  /// 从 Rust BookInfo 转换
  factory Book.fromRust(dynamic rustBookInfo) {
    return Book(
      id: rustBookInfo.bookId,
      title: rustBookInfo.title,
      author: rustBookInfo.author,
      coverPath: rustBookInfo.coverPath,
      description: '',
      filePath: rustBookInfo.filePath,
      fileType: rustBookInfo.fileType,
      fileSize: rustBookInfo.fileSize.toInt(),
      chapterCount: rustBookInfo.chapterCount,
      totalCharacters: rustBookInfo.totalCharacters.toInt(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 空书籍（用于初始化）
  factory Book.empty() {
    return Book(
      id: '',
      title: '',
      author: '',
      filePath: '',
      fileType: '',
      fileSize: 0,
      chapterCount: 0,
      totalCharacters: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
