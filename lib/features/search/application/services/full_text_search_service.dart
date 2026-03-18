/// 全书搜索服务
///
/// 基于 SQLite FTS5 实现全文搜索功能
library;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// 搜索结果
class SearchHit {
  final int chapterId;
  final String chapterTitle;
  final String snippet;
  final int position;
  final double score;

  SearchHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.position,
    required this.score,
  });
}

/// 全书搜索服务
class FullTextSearchService {
  Database? _db;
  String? _dbPath;

  /// 初始化搜索服
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _dbPath = '${dir.path}/zephyr_reader/search_index.db';
    _db = sqlite3.open(_dbPath!);

    // 创建 FTS5 虚拟
    _createSearchTable();
  }

  /// 创建搜索
  void _createSearchTable() {
    _db!.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        book_id UNINDEXED,
        chapter_id UNINDEXED,
        chapter_title,
        content,
        position UNINDEXED
      )
    ''');

    debugPrint('搜索索引表初始化完成');
  }

  /// 索引章节内容
  Future<void> indexChapter({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) async {
    if (_db == null) {
      await init();
    }

    try {
      // 分块索引（每500 字符
      const chunkSize = 500;
      final chars = content.split('');
      final totalChunks = (chars.length / chunkSize).ceil();

      final stmt = _db!.prepare('''
        INSERT INTO search_index (book_id, chapter_id, chapter_title, content, position)
        VALUES (?, ?, ?, ?, ?)
      ''');

      for (int i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = ((i + 1) * chunkSize).clamp(0, chars.length);
        final chunk = chars.sublist(start, end).join();
        final position = start;

        stmt.execute([bookId, chapterId, chapterTitle, chunk, position]);
      }

      stmt.close();
      debugPrint('章节索引完成bookId - $chapterId');
    } catch (e) {
      debugPrint('索引章节失败e');
      rethrow;
    }
  }

  /// 搜索书籍内容
  List<SearchHit> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) {
    if (_db == null) {
      throw StateError('搜索服务未初始化');
    }

    try {
      // 对搜索词进行分词（简单实现，实际应该使用 jieba 等分词器
      final tokenizedQuery = _tokenize(query);

      final stmt = _db!.prepare('''
        SELECT chapter_id, chapter_title, content, position, bm25(search_index) as score
        FROM search_index
        WHERE book_id = ? AND search_index MATCH ?
        ORDER BY score
        LIMIT ?
      ''');

      final results = <SearchHit>[];
      for (final row in stmt.select([bookId, tokenizedQuery, limit])) {
        results.add(
          SearchHit(
            chapterId: row.columnAt(0) as int,
            chapterTitle: row.columnAt(1) as String,
            snippet: _truncateSnippet(row.columnAt(2) as String),
            position: row.columnAt(3) as int,
            score: row.columnAt(4) as double,
          ),
        );
      }

      stmt.close();
      return results;
    } catch (e) {
      debugPrint('搜索失败e');
      return [];
    }
  }

  /// 删除书籍索引
  void deleteBookIndex(String bookId) {
    if (_db == null) {
      return;
    }

    try {
      _db!.execute('DELETE FROM search_index WHERE book_id = ?', [bookId]);
      debugPrint('删除书籍索引bookId');
    } catch (e) {
      debugPrint('删除索引失败e');
    }
  }

  /// 清除所有索
  void clearAll() {
    if (_db == null) {
      return;
    }

    try {
      _db!.execute('DELETE FROM search_index');
      debugPrint('清除所有索');
    } catch (e) {
      debugPrint('清除索引失败e');
    }
  }

  /// 获取索引统计
  Map<String, int> getStats() {
    if (_db == null) {
      return {};
    }

    try {
      final result = _db!.select('SELECT COUNT(*) as count FROM search_index');
      final totalCount = result.first.columnAt(0) as int;

      final bookResult = _db!.select(
        'SELECT COUNT(DISTINCT book_id) as count FROM search_index',
      );
      final bookCount = bookResult.first.columnAt(0) as int;

      return {'total_chunks': totalCount, 'book_count': bookCount};
    } catch (e) {
      debugPrint('获取统计失败e');
      return {};
    }
  }

  /// 简单分词（中文按字符，英文按单词）
  /// 注意：Rust 侧已集成 jieba 分词器，Flutter 侧使用简单分词作为降级方
  String _tokenize(String text) {
    // 使用简单分词：中文按字符，英文按空
    //  // Rust 侧已集成 jieba 分词器，提供完整的中文分词支
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// 截断摘要
  String _truncateSnippet(String text, {int maxLength = 100}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength)}...';
  }

  /// 释放资源
  void dispose() {
    if (_db != null) {
      _db!.close();
      _db = null;
    }
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

    // 添加到开
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
  /// 高亮关键
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

    // 简单实现：查找第一个匹配的
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
