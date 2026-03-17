/// 排版缓存服务（基于 Drift）
///
/// 功能：
/// - 保存排版缓存
/// - 获取排版缓存
/// - 清除缓存
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/src/rust/ffi/types.dart';

/// 排版缓存服务
class LayoutCacheService {
  final AppDatabase _db;

  LayoutCacheService(this._db);

  /// 保存排版缓存
  Future<void> saveLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
    required List<PageOffset> pageOffsets,
    required int totalPages,
  }) async {
    try {
      // 将 PageOffset 列表转换为 JSON 字符串
      final pageOffsetsJson = jsonEncode(
        pageOffsets
            .map(
              (offset) => {
                'offset': offset.offset.toInt(),
                'length': offset.length.toInt(),
              },
            )
            .toList(),
      );

      await _db.saveLayoutCache(
        bookId: bookId,
        chapterId: chapterId,
        configHash: configHash,
        pageOffsets: pageOffsetsJson,
        totalPages: totalPages,
      );

      debugPrint('保存排版缓存：book=$bookId, chapter=$chapterId, pages=$totalPages');
    } catch (e) {
      debugPrint('LayoutCacheService.saveLayoutCache error: $e');
      rethrow;
    }
  }

  /// 获取排版缓存
  Future<LayoutCacheResult?> getLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
  }) async {
    try {
      final cache = await _db.getLayoutCache(
        bookId: bookId,
        chapterId: chapterId,
        configHash: configHash,
      );

      if (cache == null) {
        return LayoutCacheResult(hit: false, cachedLayout: null);
      }

      // 将 JSON 字符串解析为 PageOffset 列表
      final pageOffsetsList = jsonDecode(cache.pageOffsets) as List<dynamic>;
      final pageOffsets = pageOffsetsList
          .map(
            (item) => PageOffset(
              offset: item['offset'] as int,
              length: item['length'] as int,
            ),
          )
          .toList();

      final cachedLayout = CachedLayout(
        chapterId: cache.chapterId,
        configHash: cache.configHash,
        pageOffsets: pageOffsets,
        totalPages: cache.totalPages,
        createdAt: cache.createdAt,
      );

      return LayoutCacheResult(hit: true, cachedLayout: cachedLayout);
    } catch (e) {
      debugPrint('LayoutCacheService.getLayoutCache error: $e');
      return LayoutCacheResult(hit: false, cachedLayout: null);
    }
  }

  /// 清除书籍的所有排版缓存
  Future<int> clearLayoutCache(int bookId) async {
    try {
      return await _db.clearLayoutCache(bookId);
    } catch (e) {
      debugPrint('LayoutCacheService.clearLayoutCache error: $e');
      return 0;
    }
  }

  /// 清除指定章节的排版缓存
  Future<int> clearChapterLayoutCache(int bookId, int chapterId) async {
    try {
      return await _db.clearChapterLayoutCache(bookId, chapterId);
    } catch (e) {
      debugPrint('LayoutCacheService.clearChapterLayoutCache error: $e');
      return 0;
    }
  }

  /// 获取书籍的所有排版缓存
  Future<List<CachedLayout>> getAllLayoutCache(int bookId) async {
    try {
      final cacheItems = await _db.getAllLayoutCache(bookId);

      return Future.wait(
        cacheItems.map((cache) async {
          final pageOffsetsList =
              jsonDecode(cache.pageOffsets) as List<dynamic>;
          final pageOffsets = pageOffsetsList
              .map(
                (item) => PageOffset(
                  offset: item['offset'] as int,
                  length: item['length'] as int,
                ),
              )
              .toList();

          return CachedLayout(
            chapterId: cache.chapterId,
            configHash: cache.configHash,
            pageOffsets: pageOffsets,
            totalPages: cache.totalPages,
            createdAt: cache.createdAt,
          );
        }),
      );
    } catch (e) {
      debugPrint('LayoutCacheService.getAllLayoutCache error: $e');
      return [];
    }
  }
}
