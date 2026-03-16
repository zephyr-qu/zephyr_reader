/// 书籍搜索服务
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/src/rust/api.dart';

import '../../../../core/database/database.dart';

/// 搜索结果
class SearchHit {
  /// 章节 ID
  final int chapterId;

  /// 章节标题
  final String chapterTitle;

  /// 匹配的文本片
  final String snippet;

  /// 匹配位置
  final int position;

  /// 相关度评
  final double score;

  /// 书籍 ID
  final int bookId;

  /// 书籍标题
  final String bookTitle;

  SearchHit({
    required this.chapterId,
    required this.chapterTitle,
    required this.snippet,
    required this.position,
    required this.score,
    required this.bookId,
    required this.bookTitle,
  });
}

/// 书籍搜索服务
class BookSearchService {
  final AppDatabase _db;
  String? _searchIndexPath;

  BookSearchService(this._db);

  /// 初始化搜索索
  Future<void> init() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final searchDir = Directory(p.join(appDir.path, 'search'));
      if (!await searchDir.exists()) {
        await searchDir.create(recursive: true);
      }

      _searchIndexPath = p.join(searchDir.path, 'search_index.db');

      // 初始Rust 搜索引擎
      // 注意：Rust 侧需要暴init_search_engine 函数
      debugPrint('搜索索引初始化完成：$_searchIndexPath');
    } catch (e) {
      debugPrint('搜索索引初始化失败：$e');
    }
  }

  /// 索引书籍
  Future<void> indexBook(
    int bookId,
    String filePath,
    List<Chapter> chapters,
  ) async {
    if (_searchIndexPath == null) {
      await init();
    }

    try {
      // 读取文件内容
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('书籍文件不存在：$filePath');
        return;
      }

      final content = await file.readAsString();

      // 调用 Rust 索引函数
      try {
        indexChapterContent(
          bookId: 'Book_$bookId',
          indexPath: _searchIndexPath!,
          chapterId: 0,
          chapterTitle: '全书',
          content: content,
        );
        debugPrint('索引书籍完成：bookId=$bookId, 字符${content.length}');
      } catch (e) {
        debugPrint('Rust 索引失败e');
      }
    } catch (e) {
      debugPrint('索引书籍失败e');
    }
  }

  /// 搜索书籍内容
  Future<List<SearchHit>> search(
    String query, {
    int? bookId,
    int limit = 50,
  }) async {
    if (_searchIndexPath == null) {
      await init();
    }

    if (_searchIndexPath == null) {
      debugPrint('搜索索引路径未初始化');
      return [];
    }

    try {
      // 调用 Rust 搜索函数
      try {
        final rustResults = searchInBook(
          bookId: bookId != null ? 'Book_$bookId' : '',
          indexPath: _searchIndexPath!,
          query: query,
          limit: limit,
        );

        // 转换SearchHit 列表
        return rustResults.hits
            .map(
              (hit) => SearchHit(
                chapterId: hit.chapterId,
                chapterTitle: hit.chapterTitle,
                snippet: hit.snippet,
                position: hit.position,
                score: hit.score,
                bookId: bookId ?? 0,
                bookTitle: '', // 需要从数据库获
              ),
            )
            .toList();
      } catch (e) {
        debugPrint('Rust 搜索失败e');
        // 降级使用数据库搜
        return await _searchInDatabase(query, bookId: bookId, limit: limit);
      }
    } catch (e) {
      debugPrint('搜索失败e');
      return [];
    }
  }

  /// 在数据库中搜索（临时实现
  Future<List<SearchHit>> _searchInDatabase(
    String query, {
    int? bookId,
    int limit = 50,
  }) async {
    try {
      // 搜索章节标题
      var chapters = await _db.getChaptersByBookId(bookId ?? 0);

      // 过滤关键
      final lowerQuery = query.toLowerCase();
      chapters = chapters
          .where((c) => c.title.toLowerCase().contains(lowerQuery))
          .toList();

      // 获取书籍信息
      final bookTitles = <int, String>{};
      if (bookId != null) {
        final book = await _db.getBookById(bookId);
        if (book != null) {
          bookTitles[bookId] = book.title;
        }
      } else {
        final books = await _db.getAllBooks();
        for (final book in books) {
          bookTitles[book.id] = book.title;
        }
      }

      // 转换为搜索结
      final hits = <SearchHit>[];
      for (final chapter in chapters.take(limit)) {
        hits.add(
          SearchHit(
            chapterId: chapter.id,
            chapterTitle: chapter.title,
            snippet: chapter.title, // 临时使用标题作为片段
            position: 0,
            score: 1.0,
            bookId: chapter.bookId,
            bookTitle: bookTitles[chapter.bookId] ?? '未知书籍',
          ),
        );
      }

      return hits;
    } catch (e) {
      debugPrint('数据库搜索失败：$e');
      return [];
    }
  }

  /// 删除书籍索引
  Future<void> removeBookIndex(int bookId) async {
    try {
      // 调用 Rust 删除索引函数
      final success = deleteSearchIndex(
        bookId: 'Book_$bookId',
        indexPath: _searchIndexPath ?? '',
      );
      if (success) {
        debugPrint('删除书籍索引完成：bookId=$bookId');
      } else {
        debugPrint('删除书籍索引失败：bookId=$bookId');
      }
    } catch (e) {
      debugPrint('删除索引失败e');
    }
  }

  /// 清除所有索
  Future<void> clearAllIndex() async {
    try {
      // 调用 Rust 清除索引函数
      final success = clearAllSearchIndex(indexPath: _searchIndexPath ?? '');
      if (success) {
        debugPrint('清除所有索引完');
      } else {
        debugPrint('清除所有索引失');
      }
    } catch (e) {
      debugPrint('清除索引失败e');
    }
  }

  /// 重建所有书籍索
  Future<void> rebuildAllIndexes() async {
    try {
      final books = await _db.getAllBooks();
      debugPrint('开始重建索引，${books.length} 本书');

      for (final book in books) {
        final chapters = await _db.getChaptersByBookId(book.id);
        await indexBook(book.id, book.filePath, chapters);
      }

      debugPrint('索引重建完成');
    } catch (e) {
      debugPrint('重建索引失败e');
    }
  }
}
