/// 书籍搜索服务
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/local/rust_search_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 搜索结果
class SearchHit {
  /// 书籍 ID
  final String bookId;

  /// 章节索引
  final int chapterIndex;

  /// 章节标题
  final String chapterTitle;

  /// 匹配的文本片段
  final String snippet;

  /// 内容
  final String content;

  /// 相关度评分
  final double rank;

  SearchHit({
    required this.bookId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
    required this.content,
    required this.rank,
  });
}

/// 书籍搜索服务
class BookSearchService {
  final RustSearchService _search;
  String? _searchIndexPath;

  BookSearchService(this._search);

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
    String bookId,
    String filePath,
    List<DbChapter> chapters,
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
        await _search.indexChapterContent(
          bookId: bookId,
          chapterId: 0,
          chapterTitle: '全书',
          content: content,
        );
        debugPrint('索引书籍完成：bookId=$bookId, 字符${content.length}');
      } catch (e) {
        debugPrint('Rust 索引失败：$e');
      }
    } catch (e) {
      debugPrint('索引书籍失败：$e');
    }
  }

  /// 搜索书籍内容
  Future<List<SearchHit>> search(
    String query, {
    String? bookId,
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
      // 使用独立的 search 模块进行搜索
      final searchResults = _search.searchInBook(
        bookId: bookId ?? '',
        query: query,
        limit: limit,
      );

      // 转换 Rust 搜索结果为 SearchHit
      final hits =
          (searchResults as dynamic).value.map((result) {
            return SearchHit(
              bookId: result.bookId,
              chapterIndex: result.chapterId.toInt(),
              chapterTitle: result.chapterTitle,
              snippet: result.snippet,
              content: result.content,
              rank: result.rank,
            );
          }).toList() ??
          [];

      debugPrint('搜索完成：query=$query, 结果数=${hits.length}');
      return hits;
    } catch (e) {
      debugPrint('搜索失败：$e');
      return [];
    }
  }

  /// 删除书籍索引
  Future<void> removeBookIndex(String bookId) async {
    try {
      // 注意：search 模块目前没有单独的删除索引 API
      // 可以通过重新索引空内容来实现，或者等待 Rust 侧添加该功能
      debugPrint('删除书籍索引：bookId=$bookId (待 Rust search API 完善)');
    } catch (e) {
      debugPrint('删除书籍索引失败：bookId=$bookId, error=$e');
    }
  }

  /// 清除所有索引
  Future<void> clearAllIndex() async {
    try {
      // 调用 Rust 清除索引函数
      await _search.clearAllSearchIndex();
      debugPrint('清除所有索引完成');
    } catch (e) {
      debugPrint('清除所有索引失败：$e');
    }
  }

  /// 重建所有书籍索引
  ///
  /// 注意：此方法需要从 Rust API 获取书籍列表
  Future<void> rebuildAllIndexes() async {
    try {
      // TODO: 从 Rust API 获取所有书籍信息
      debugPrint('重建索引功能待实现，需要从 Rust API 获取书籍列表');
      // final books = await getAllBooks(); // 从 Rust API 获取
      // for (final book in books) {
      //   await indexBook(book.bookId, book.filePath, book.chapters);
      // }
      debugPrint('索引重建待实现');
    } catch (e) {
      debugPrint('重建索引失败：$e');
    }
  }
}
