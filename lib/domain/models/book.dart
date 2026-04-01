/// 书籍统一领域模型
///
/// 作为 Flutter 应用的核心数据模型，与 Rust 侧的 BookInfo 对齐
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/utils/logging.dart';

part 'book.freezed.dart';

/// 书籍领域模型
@freezed
abstract class Book with _$Book {
  const factory Book({
    required int id,

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

    /// 文件类型（txt, epub, pdf）
    required String fileType,

    /// 文件大小（字节）
    required int fileSize,

    /// 总章节数
    required int totalChapters,

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

    /// 分类 ID 列表
    @Default(<int>[]) List<int> categoryIds,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,

    /// 最后阅读时间
    DateTime? lastReadAt,
  }) = _Book;

  /// 从数据库模型转换
  factory Book.fromDb(dynamic dbBook) {
    try {
      // 解析分类 ID 列表（JSON 字符串）
      List<int> categoryIds = [];
      if (dbBook.categoryIds != null && dbBook.categoryIds is String) {
        try {
          final decoded = (dbBook.categoryIds as String).isNotEmpty
              ? jsonDecode(dbBook.categoryIds) as List
              : [];
          categoryIds = decoded.cast<int>();
        } catch (e) {
          Logging.debug('解析 categoryIds 失败：$e');
        }
      }

      return Book(
        id: dbBook.id ?? 0,
        title: dbBook.title ?? '',
        author: dbBook.author ?? '',
        coverPath: dbBook.coverPath,
        description: dbBook.description,
        filePath: dbBook.filePath ?? '',
        fileType: dbBook.fileType ?? '',
        fileSize: dbBook.fileSize ?? 0,
        totalChapters: dbBook.totalChapters ?? 0,
        totalCharacters: dbBook.totalCharacters ?? 0,
        currentChapterId: dbBook.currentChapterId,
        currentPageIndex: dbBook.currentPageIndex ?? 0,
        totalPages: dbBook.totalPages ?? 0,
        progress: dbBook.progress ?? 0.0,
        status: dbBook.status ?? 'reading',
        isPinned: dbBook.isPinned ?? false,
        categoryIds: categoryIds,
        createdAt: dbBook.createdAt ?? DateTime.now(),
        updatedAt: dbBook.updatedAt ?? DateTime.now(),
        lastReadAt: dbBook.lastReadAt,
      );
    } catch (e, stackTrace) {
      Logging.debug('Book.fromDb 转换失败：$e');
      Logging.debug('Stack trace: $stackTrace');
      Logging.debug('dbBook: $dbBook');
      rethrow;
    }
  }

  /// 空书籍（用于初始化）
  factory Book.empty() {
    return Book(
      id: 0,
      title: '',
      author: '',
      filePath: '',
      fileType: '',
      fileSize: 0,
      totalChapters: 0,
      totalCharacters: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
