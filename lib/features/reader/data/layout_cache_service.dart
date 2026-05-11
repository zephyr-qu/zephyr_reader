/// 排版缓存服务（基于 Rust）
library;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 排版缓存结果
class LayoutCacheResult {
  final bool hit;
  final LayoutCache? cachedLayout;

  const LayoutCacheResult({required this.hit, required this.cachedLayout});
}

@injectable
class LayoutCacheService {
  final RustStorageService _storage;
  LayoutCacheService(this._storage);

  Future<void> saveLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
    required List<(int, int)> pageOffsets,
    required int totalPages,
  }) async {
    try {
      final cache = LayoutCache(
        pageOffsets: pageOffsets.map((o) => (o.$1, o.$2)).toList(),
        totalPages: totalPages,
        createdAt: DateTime.now(),
      );
      final key = LayoutCacheKey(
        bookId: 'book_$bookId',
        chapterIndex: chapterId,
        configHash: configHash,
      );
      await _storage.saveLayoutCache(cache: cache, key: key);
      debugPrint('保存排版缓存：book=$bookId, chapter=$chapterId, pages=$totalPages');
    } catch (e) {
      debugPrint('LayoutCacheService.saveLayoutCache error: $e');
      rethrow;
    }
  }

  Future<LayoutCacheResult?> getLayoutCache({
    required int bookId,
    required int chapterId,
    required String configHash,
  }) async {
    try {
      final cache = await _storage.getLayoutCache(
        bookId: 'book_$bookId',
        chapterIndex: chapterId,
        configHash: configHash,
      );
      if (cache == null) {
        return const LayoutCacheResult(hit: false, cachedLayout: null);
      }
      return LayoutCacheResult(hit: true, cachedLayout: cache);
    } catch (e) {
      debugPrint('LayoutCacheService.getLayoutCache error: $e');
      return const LayoutCacheResult(hit: false, cachedLayout: null);
    }
  }

  Future<int> clearLayoutCache(int bookId) async {
    try {
      await _storage.clearLayoutCache('book_$bookId');
      return 0;
    } catch (e) {
      debugPrint('LayoutCacheService.clearLayoutCache error: $e');
      return 0;
    }
  }

  Future<int> clearChapterLayoutCache(int bookId, int chapterId) async {
    try {
      return await clearLayoutCache(bookId);
    } catch (e) {
      debugPrint('LayoutCacheService.clearChapterLayoutCache error: $e');
      return 0;
    }
  }

  Future<List<LayoutCache>> getAllLayoutCache(int bookId) async {
    try {
      return [];
    } catch (e) {
      debugPrint('LayoutCacheService.getAllLayoutCache error: $e');
      return [];
    }
  }
}
