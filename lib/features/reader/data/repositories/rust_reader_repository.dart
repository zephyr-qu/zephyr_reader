/// 阅读器仓库
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分页信息
class PageInfo {
  final int pageIndex;
  final String content;
  final int startOffset;
  final int endOffset;
  PageInfo({required this.pageIndex, required this.content, required this.startOffset, required this.endOffset});
}

/// 章节内容缓存项
class ChapterCacheItem {
  final String content;
  final List<PageInfo> pages;
  final DateTime loadedAt;
  ChapterCacheItem({required this.content, required this.pages, required this.loadedAt});
}

/// 阅读进度数据
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;
  ReadingProgressData({required this.bookId, required this.chapterIndex, required this.pageIndex, required this.totalPages, required this.readingTimeSeconds, required this.lastReadAt});
  double get progressPercent => totalPages > 0 ? (pageIndex + 1) / totalPages : 0.0;
  String get progressText => '${(progressPercent * 100).toStringAsFixed(1)}%';
}

@Injectable()
class ReaderRepository {
  final RustStorageService _storage;
  final Map<String, Map<int, ChapterCacheItem>> _cache = {};
  static const int maxCacheSize = 10;
  ReadingProgressData? _currentProgress;

  ReaderRepository(this._storage);

  
  Future<Chapter?> getChapter(int bookId, int chapterIndex) async {
    final chapters = await _storage.getChaptersByBook('book_$bookId');
    try {
      return chapters.firstWhere((c) => c.chapterIndex == chapterIndex);
    } catch (_) {
      return null;
    }
  }

  Future<List<Chapter>> getChapters(int bookId) async {
    return _storage.getChaptersByBook('book_$bookId');
  }

  Future<void> saveReadingHistory(
    String bookId,
    int chapterId,
    int position,
    int duration,
  ) async {
    final now = DateTime.now();
    await _storage.recordReadingSession(ReadingSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      startCharOffset: 0,
      endCharOffset: position,
      startedAt: now,
      endedAt: now,
      durationSeconds: duration,
    ));
  }

  Future<GlobalStats?> getReadingHistory(int bookId) async {
    return _storage.getGlobalReadingStats();
  }

  Future<int> addBookmark(
    String bookId,
    int chapterId,
    int position,
  ) async {
    final bookmark = Bookmark(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      charOffset: position,
      title: '书签',
      createdAt: DateTime.now(),
    );
    await _storage.createBookmark(bookmark);
    return bookmark.id.hashCode;
  }

  Future<List<Bookmark>> getBookmarks(String bookId) async {
    return _storage.getBookmarks('book_$bookId');
  }

  Future<bool> deleteBookmark(int bookmarkId) async {
    try {
      await _storage.deleteBookmark('bm_$bookmarkId');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getChapterContent(String contentFile) async {
    final file = File(contentFile);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  // ===== From ChapterContentService =====

  Future<String> loadChapterContent(String bookId, int chapterId, {String? contentFilePath}) async {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }
    try {
      String content;
      if (contentFilePath != null && contentFilePath.isNotEmpty) {
        content = '';
      } else {
        throw Exception('章节文件路径未提供');
      }
      if (content.isEmpty) throw Exception('Rust API 返回空内容');
      _updateCache(cacheKey, chapterId, content, []);
      return content;
    } catch (e) {
      throw Exception('加载章节内容失败：$e');
    }
  }

  Future<List<PageInfo>> calculatePages({
    required String bookId, required int chapterId,
    required double fontSize, required double lineHeight,
    required double width, required double height, required double padding,
  }) async {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }
    final content = await loadChapterContent(bookId, chapterId);
    try {
      final pages = _fallbackPaginateContent(content);
      if (pages.isNotEmpty) _updateCache(cacheKey, chapterId, content, pages);
      return pages;
    } catch (e) {
      debugPrint('ReaderRepository.calculatePages error: $e');
      return _fallbackPaginateContent(content);
    }
  }

  List<PageInfo> _fallbackPaginateContent(String content) {
    const int charsPerPage = 2000;
    final pages = <PageInfo>[];
    var offset = 0;
    var pageIndex = 0;
    while (offset < content.length) {
      final endOffset = (offset + charsPerPage).clamp(0, content.length);
      pages.add(PageInfo(pageIndex: pageIndex, content: content.substring(offset, endOffset), startOffset: offset, endOffset: endOffset));
      offset = endOffset;
      pageIndex++;
    }
    if (pages.isEmpty) pages.add(PageInfo(pageIndex: 0, content: content, startOffset: 0, endOffset: content.length));
    return pages;
  }

  void _updateCache(String cacheKey, int chapterId, String content, List<PageInfo> pages) {
    if (_cache.length >= maxCacheSize) _clearOldestCache();
    if (!_cache.containsKey(cacheKey)) _cache[cacheKey] = {};
    _cache[cacheKey]![chapterId] = ChapterCacheItem(content: content, pages: pages, loadedAt: DateTime.now());
  }

  void _clearOldestCache() {
    if (_cache.isEmpty) return;
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _cache.entries) {
      for (final chapterEntry in entry.value.entries) {
        if (oldestTime == null || chapterEntry.value.loadedAt.isBefore(oldestTime)) {
          oldestTime = chapterEntry.value.loadedAt;
          oldestKey = entry.key;
        }
      }
    }
    if (oldestKey != null) _cache.remove(oldestKey);
  }

  void clearBookCache(int bookId) => _cache.remove(bookId.toString());
  void clearAllCache() => _cache.clear();

  String? getCachedContent(int bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.content;
    }
    return null;
  }

  List<PageInfo>? getCachedPages(String bookId, int chapterId) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      return _cache[cacheKey]![chapterId]!.pages;
    }
    return null;
  }

  String? getPageContent(int bookId, int chapterId, int pageIndex) {
    final cacheKey = bookId.toString();
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.containsKey(chapterId)) {
      final pages = _cache[cacheKey]![chapterId]!.pages;
      if (pageIndex >= 0 && pageIndex < pages.length) return pages[pageIndex].content;
    }
    return null;
  }

  // ===== From ReadingProgressService =====

  Future<void> updateReadingProgress({
    required String bookId, required int chapterId,
    required int pageIndex, required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    final now = DateTime.now();
    final progress = (pageIndex + 1) / (totalPages > 0 ? totalPages : 1);
    await _storage.saveReadingProgress(ReadingProgress(
      bookId: bookId, chapterIndex: chapterId,
      charOffset: 0, progress: progress.clamp(0.0, 1.0),
      readingTimeSeconds: readingTimeSeconds, lastReadAt: now,
      isCompleted: progress >= 1.0,
    ));
    _currentProgress = ReadingProgressData(bookId: bookId, chapterIndex: chapterId, pageIndex: pageIndex, totalPages: totalPages, readingTimeSeconds: readingTimeSeconds, lastReadAt: now);
  }

  Future<ReadingProgressData?> loadReadingProgress(String bookId) async {
    if (_currentProgress != null && _currentProgress!.bookId == bookId) return _currentProgress;
    final progress = await _storage.getReadingProgress(bookId);
    if (progress == null) return null;
    _currentProgress = ReadingProgressData(bookId: bookId, chapterIndex: progress.chapterIndex, pageIndex: 0, totalPages: 0, readingTimeSeconds: progress.readingTimeSeconds.toInt(), lastReadAt: progress.lastReadAt);
    return _currentProgress;
  }

  ReadingProgressData? get currentProgress => _currentProgress;

  Future<void> clearReadingProgress(String bookId) async {
    await _storage.clearReadingProgress(bookId);
    if (_currentProgress?.bookId == bookId) _currentProgress = null;
  }

  Future<List<ReadingProgressData>> getAllReadingProgress() async {
    final books = await _storage.getAllBooks();
    final result = <ReadingProgressData>[];
    for (final book in books) {
      final progress = await _storage.getReadingProgress(book.bookId);
      if (progress != null) {
        result.add(ReadingProgressData(bookId: book.bookId, chapterIndex: progress.chapterIndex, pageIndex: 0, totalPages: 0, readingTimeSeconds: progress.readingTimeSeconds.toInt(), lastReadAt: progress.lastReadAt));
      }
    }
    return result;
  }

  void clearProgressCache() => _currentProgress = null;
}
