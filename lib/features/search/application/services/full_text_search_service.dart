library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/local/rust_search_service.dart';

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

@Singleton()
class FullTextSearchService {
  final RustSearchService _searchService;
  bool _initialized = false;

  FullTextSearchService(this._searchService);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(dir.path, 'zephyr_reader', 'search_index.db');
      final searchDir = p.dirname(dbPath);
      final searchDirObj = Directory(searchDir);
      if (!await searchDirObj.exists()) {
        await searchDirObj.create(recursive: true);
      }

      await _searchService.init();
      _initialized = true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> indexChapter({
    required String bookId,
    required int chapterId,
    required String chapterTitle,
    required String content,
  }) async {
    if (!_initialized) await init();
    await _searchService.indexChapterContent(
      bookId: bookId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      content: content,
    );
  }

  Future<List<SearchHit>> search({
    required String bookId,
    required String query,
    int limit = 50,
  }) async {
    if (!_initialized) await init();
    try {
      final results = await _searchService.searchInBook(
        bookId: bookId,
        query: query,
        limit: limit,
      );
      return results
          .map(
            (item) => SearchHit(
              bookId: bookId,
              chapterId: item.chapterId,
              chapterTitle: item.chapterTitle,
              snippet: item.snippet,
              position: item.position.toInt(),
              score: item.score,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteBookIndex(String bookId) async {
    if (!_initialized) return;
    await _searchService.deleteBookSearchIndex(bookId);
  }

  Future<void> clearAll() async {
    if (!_initialized) return;
    await _searchService.clearAllSearchIndex();
  }

  void dispose() {
    _initialized = false;
  }
}

class SearchHistoryService {
  final List<String> _history = [];
  static const int maxHistory = 20;

  List<String> getHistory() => List.unmodifiable(_history);

  void addHistory(String query) {
    if (query.trim().isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > maxHistory) _history.removeLast();
  }

  void clearHistory() => _history.clear();

  void removeHistory(String query) => _history.remove(query);
}

class SearchHighlighter {
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

  static List<TextSpan> highlightToSpans({
    required String text,
    required List<String> keywords,
    TextStyle? normalStyle,
    TextStyle? highlightStyle,
  }) {
    if (keywords.isEmpty) return [TextSpan(text: text, style: normalStyle)];
    final spans = <TextSpan>[];
    String remaining = text;
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
