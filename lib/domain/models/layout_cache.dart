/// 排版缓存领域模型
library;


import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:zephyr_reader/core/database/database.dart';

part 'layout_cache.freezed.dart';

/// 排版缓存领域模型
@freezed
abstract class LayoutCache with _$LayoutCache {
  const factory LayoutCache({
    /// 自增主键
    required int id,

    /// 书籍 ID
    required int bookId,

    /// 章节 ID
    required int chapterId,

    /// 排版配置哈希
    required String configHash,

    /// 页面偏移量列表（JSON 格式）
    required String pageOffsets,

    /// 总页数
    required int totalPages,

    /// 创建时间戳（Unix 时间戳，秒）
    required int createdAt,
  }) = _LayoutCache;

  /// 从数据库模型转换
  factory LayoutCache.fromDb(DbLayoutCache db) {
    return LayoutCache(
      id: db.id,
      bookId: db.bookId,
      chapterId: db.chapterId,
      configHash: db.configHash,
      pageOffsets: db.pageOffsets,
      totalPages: db.totalPages,
      createdAt: db.createdAt,
    );
  }

  /// 空缓存
  factory LayoutCache.empty() {
    return LayoutCache(
      id: 0,
      bookId: 0,
      chapterId: 0,
      configHash: '',
      pageOffsets: '',
      totalPages: 0,
      createdAt: 0,
    );
  }
}


