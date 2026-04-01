import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/database/database.dart';

import 'rust_pagination_service.dart';

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
class ChapterContentService {
  final AppDatabase _database;
  final RustPaginationService _paginationService;

  /// 内存缓存：bookId -> chapterId -> ChapterCacheItem
  final Map<String, Map<int, ChapterCacheItem>> _cache = {};

  /// 缓存大小限制
  static const int maxCacheSize = 10;

  ChapterContentService(this._database)
      : _paginationService = RustPaginationService();

  /// 加载章节内容
  Future<String> loadChapterContent(int bookId, int chapterId) async {
    final cacheKey = bookId.toString();
    
    // 检查缓存
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }

    try {
      // 从数据库获取章节信息
      final chapter = await _database.getChapter(bookId, chapterId);
      if (chapter == null) {
        throw Exception('章节不存在');
      }

      // 读取章节内容文件
      final contentFile = chapter.contentFile;
      if (contentFile.isEmpty) {
        throw Exception('章节文件路径为空');
      }

      final file = File(contentFile);
      if (!await file.exists()) {
        throw Exception('章节文件不存在：$contentFile');
      }

      final content = await file.readAsString();

      // 更新缓存
      _updateCache(cacheKey, chapterId, content, []);

      return content;
    } catch (e) {
      throw Exception('加载章节内容失败：$e');
    }
  }

  /// 计算分页
  Future<List<PageInfo>> calculatePages({
    required int bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) async {
    final cacheKey = bookId.toString();

    // 检查缓存
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }

    // 加载内容
    final content = await loadChapterContent(bookId, chapterId);

    try {
      // 使用 Rust 引擎分页
      final pages = await _paginationService.paginateContent(
        content: content,
        chapterId: chapterId,
        fontSize: fontSize,
        lineHeight: lineHeight,
        pageWidth: width,
        pageHeight: height,
        padding: padding,
      );

      // 转换为 PageInfo 列表
      final pageInfos = pages
          .asMap()
          .entries
          .map((entry) => PageInfo(
                pageIndex: entry.key,
                content: entry.value.content,
                startOffset: content.indexOf(entry.value.content),
                endOffset: content.indexOf(entry.value.content) +
                    entry.value.content.length,
              ))
          .toList();

      // 更新缓存
      if (pageInfos.isNotEmpty) {
        _updateCache(cacheKey, chapterId, content, pageInfos);
      }

      return pageInfos;
    } catch (e) {
      debugPrint('ChapterContentService.calculatePages error: $e');
      // 如果 Rust 分页失败，使用简化的字符估算方法
      return _fallbackPaginateContent(content, chapterId, fontSize, lineHeight);
    }
  }

  /// fallback 分页方法（当 Rust 引擎不可用时）
  List<PageInfo> _fallbackPaginateContent(
    String content,
    int chapterId,
    double fontSize,
    double lineHeight,
  ) {
    // 简化的字符估算（每页约 2000 字符）
    const int charsPerPage = 2000;
    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;

    while (offset < content.length) {
      final endOffset = (offset + charsPerPage).clamp(0, content.length);
      final pageContent = content.substring(offset, endOffset);

      pages.add(PageInfo(
        pageIndex: pageIndex,
        content: pageContent,
        startOffset: offset,
        endOffset: endOffset,
      ));

      offset = endOffset;
      pageIndex++;
    }

    if (pages.isEmpty) {
      pages.add(PageInfo(
        pageIndex: 0,
        content: content,
        startOffset: 0,
        endOffset: content.length,
      ));
    }

    return pages;
  }

  /// 更新缓存
  void _updateCache(
    String cacheKey,
    int chapterId,
    String content,
    List<PageInfo> pages,
  ) {
    // 检查是否需要清理缓存
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

  /// 清理最旧的缓存
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

  /// 清除指定书籍的缓存
  void clearBookCache(int bookId) {
    _cache.remove(bookId.toString());
  }

  /// 清除所有缓存
  void clearAllCache() {
    _cache.clear();
  }

  /// 获取缓存的章节内容
  String? getCachedContent(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }
    return null;
  }

  /// 获取缓存的页数
  int? getCachedTotalPages(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages.length;
    }
    return null;
  }

  /// 获取缓存的页面列表
  List<PageInfo>? getCachedPages(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) &&
        _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }
    return null;
  }

  /// 获取指定页的内容
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
