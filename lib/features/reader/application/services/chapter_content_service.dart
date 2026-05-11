import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';

/// 分页信息
class PageInfo {
  final int pageIndex;
  final String content;
  final int startOffset;
  final int endOffset;

  PageInfo({
    required this.pageIndex,
    required this.content,
    required this.startOffset,
    required this.endOffset,
  });
}

/// 章节内容缓存项
class ChapterCacheItem {
  final String content;
  final List<PageInfo> pages;
  final DateTime loadedAt;

  ChapterCacheItem({
    required this.content,
    required this.pages,
    required this.loadedAt,
  });
}

/// 章节内容服务
///
/// 负责加载和管理章节内容，支持分页计算和内存缓存
/// 使用 Rust API 提取章节内容，实现统一的解析流程
@injectable
class ChapterContentService {
  /// 内存缓存：bookId -> chapterId -> ChapterCacheItem
  final Map<String, Map<int, ChapterCacheItem>> _cache = {};

  /// 缓存大小限制
  static const int maxCacheSize = 10;

  ChapterContentService();

  /// 加载章节内容
  Future<String> loadChapterContent(
    String bookId,
    int chapterId, {
    String? contentFilePath,
  }) async {
    final cacheKey = bookId.toString();

    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }

    try {
      String content;

      if (contentFilePath != null && contentFilePath.isNotEmpty) {
        content = '';
      } else {
        throw Exception('章节文件路径未提供');
      }

      if (content.isEmpty) {
        throw Exception('Rust API 返回空内容');
      }

      _updateCache(cacheKey, chapterId, content, []);
      return content;
    } catch (e) {
      throw Exception('加载章节内容失败：$e');
    }
  }

  /// 计算分页
  Future<List<PageInfo>> calculatePages({
    required String bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) async {
    final cacheKey = bookId.toString();

    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }

    final content = await loadChapterContent(bookId, chapterId);

    try {
      final pages = _fallbackPaginateContent(content);
      if (pages.isNotEmpty) {
        _updateCache(cacheKey, chapterId, content, pages);
      }
      return pages;
    } catch (e) {
      debugPrint('ChapterContentService.calculatePages error: $e');
      return _fallbackPaginateContent(content);
    }
  }

  /// fallback 分页方法
  List<PageInfo> _fallbackPaginateContent(String content) {
    const int charsPerPage = 2000;
    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;

    while (offset < content.length) {
      final endOffset = (offset + charsPerPage).clamp(0, content.length);
      final pageContent = content.substring(offset, endOffset);

      pages.add(
        PageInfo(
          pageIndex: pageIndex,
          content: pageContent,
          startOffset: offset,
          endOffset: endOffset,
        ),
      );

      offset = endOffset;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(
        PageInfo(
          pageIndex: 0,
          content: content,
          startOffset: 0,
          endOffset: content.length,
        ),
      );
    }

    return pages;
  }

  void _updateCache(
    String cacheKey,
    int chapterId,
    String content,
    List<PageInfo> pages,
  ) {
    if (_cache.length >= maxCacheSize) {
      _clearOldestCache();
    }

    if (!_cache.containsKey(cacheKey)) {
      _cache[cacheKey] = {};
    }

    _cache[cacheKey]![chapterId] = ChapterCacheItem(
      content: content,
      pages: pages,
      loadedAt: DateTime.now(),
    );
  }

  void _clearOldestCache() {
    if (_cache.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cache.entries) {
      for (final chapterEntry in entry.value.entries) {
        if (oldestTime == null ||
            chapterEntry.value.loadedAt.isBefore(oldestTime)) {
          oldestTime = chapterEntry.value.loadedAt;
          oldestKey = entry.key;
        }
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  void clearBookCache(int bookId) {
    _cache.remove(bookId.toString());
  }

  void clearAllCache() {
    _cache.clear();
  }

  String? getCachedContent(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }
    return null;
  }

  int? getCachedTotalPages(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages.length;
    }
    return null;
  }

  List<PageInfo>? getCachedPages(String bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }
    return null;
  }

  String? getPageContent(int bookId, int chapterId, int pageIndex) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      final pages = _cache[cacheKey]![chapterId]!.pages;
      if (pageIndex >= 0 && pageIndex < pages.length) {
        return pages[pageIndex].content;
      }
    }
    return null;
  }
}
