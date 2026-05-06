/// 全书搜索服务
///
/// 基于 Rust FTS5 搜索 API 实现全文搜索功能
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as rust_search;

/// 搜索结果
class SearchHit {
  final String bookId;
  final int chapterId;
  final String chapterTitle;
  final String snippet;
  final int position;
  final double score;

  SearchHit({
    required this.bookId,
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.position,
    required this.score,
  });
}

/// 全书搜索服务
class FullTextSearchService {
  bool _initialized = false;

  /// 初始化搜索服务
  Future<void> init() async {
    if (_initialized) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'zephyr_reader', 'search_index.db');

      // 确保目录存在
      final searchDir = p.dirname(dbPath);
      final searchDirObj = Directory(searchDir);
      if (!await searchDirObj.exists()) {
        await searchDirObj.create(recursive: true);
      }

      // 初始化 Rust 搜索引擎
      await rust_search.initSearchEngine(dbPath: dbPath);

      _initialized = true;
      debugPrint('搜索索引初始化完成：$dbPath');
    } catch (e) {
      debugPrint('搜索索引初始化失败：$e');
      rethrow;
    }
  }

  /// 索引章节内容
  Future<void> indexChapter({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) async {
    if (!_initialized) {
      await init();
    }

    try {
      await rust_search.indexChapterContent(
        bookId: bookId,
        chapterId: chapterId,
        chapterTitle: chapterTitle,
        content: content,
      );
      debugPrint('章节索引完成：bookId=$bookId, chapterId=$chapterId');
        } catch (e) {
      debugPrint('索引章节失败：$e');
      rethrow;
    }
  }

  /// 搜索书籍内容
  Future<List<SearchHit>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) async {
    if (!_initialized) {
      await init();
    }

    try {
      final result = rust_search.searchInBook(
        bookId: bookId,
        query: query,
        limit: limit,
      );
      final rawList = (result as dynamic).value as List<dynamic>? ?? [];
      return rawList.map((item) {
        return SearchHit(
          bookId: bookId,
          chapterId: (item.chapterId ?? item.chapter_id ?? 0) as int,
          chapterTitle: (item.chapterTitle ?? item.chapter_title ?? '') as String,
          snippet: (item.snippet ?? '') as String,
          position: (item.position ?? 0) as int,
          score: (item.score ?? 0.0).toDouble(),
        );
      }).toList();
    } catch (e) {
      debugPrint('搜索失败：$e');
      return [];
    }
  }

  /// 删除书籍索引
  void deleteBookIndex(String bookId) {
    if (!_initialized) return;

    try {
      // Rust API 目前没有单独的 delete_book_index 函数
      // 可以通过重新索引或删除整个索引来实现
      debugPrint('删除书籍索引（待 Rust API 完善）：bookId=$bookId');
    } catch (e) {
      debugPrint('删除索引失败：$e');
    }
  }

  /// 清除所有索引
  void clearAll() {
    if (!_initialized) return;

    try {
      rust_search.clearAllSearchIndex();
      debugPrint('清除所有索引完成');
    } catch (e) {
      debugPrint('清除索引失败：$e');
    }
  }

  /// 释放资源
  void dispose() {
    _initialized = false;
  }
}

/// 搜索历史服务
class SearchHistoryService {
  final List<String> _history = [];
  static const int maxHistory = 20;

  /// 获取搜索历史
  List<String> getHistory() {
    return List.unmodifiable(_history);
  }

  /// 添加搜索历史
  void addHistory(String query) {
    if (query.trim().isEmpty) return;

    // 移除重复
    _history.remove(query);

    // 添加到开头
    _history.insert(0, query);

    // 限制历史记录数量
    if (_history.length > maxHistory) {
      _history.removeLast();
    }
  }

  /// 清除搜索历史
  void clearHistory() {
    _history.clear();
  }

  /// 删除单条历史
  void removeHistory(String query) {
    _history.remove(query);
  }
}

/// 搜索高亮工具
class SearchHighlighter {
  /// 高亮关键词
  static String highlight({
    required String text,
    required List<String> keywords,
    String openTag = '<span class="highlight">',
    String closeTag = '</span>',
  }) {
    String result = text;

    for (final keyword in keywords) {
      if (keyword.trim().isEmpty) continue;

      final regex = RegExp('($keyword)', caseSensitive: false);
      result = result.replaceAll(regex, '$openTag$keyword$closeTag');
    }

    return result;
  }

  /// 高亮并转换为 RichText Spans
  static List<TextSpan> highlightToSpans({
    required String text,
    required List<String> keywords,
    TextStyle? normalStyle,
    TextStyle? highlightStyle,
  }) {
    if (keywords.isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    final spans = <TextSpan>[];
    String remaining = text;

    // 简单实现：查找第一个匹配的关键
    for (final keyword in keywords) {
      final index = remaining.toLowerCase().indexOf(keyword.toLowerCase());
      if (index == -1) continue;

      if (index > 0) {
        spans.add(
          TextSpan(text: remaining.substring(0, index), style: normalStyle),
        );
      }

      spans.add(
        TextSpan(
          text: remaining.substring(index, index + keyword.length),
          style: highlightStyle,
        ),
      );

      remaining = remaining.substring(index + keyword.length);
    }

    if (remaining.isNotEmpty) {
      spans.add(TextSpan(text: remaining, style: normalStyle));
    }

    return spans;
  }
}