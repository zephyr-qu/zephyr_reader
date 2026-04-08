/// 书籍搜索服务
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/api/storage.dart' as storage_api;
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
  String? _searchIndexPath;

  BookSearchService();

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
        await search_api.indexChapterContent(
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
      // 调用 Rust 搜索函数
      try {
        await storage_api.searchContent(
          query: query,
          bookId: bookId,
        );

        // ApiResultVecDbSearchResult 是 RustOpaqueInterface，暂时无法直接获取值
        // 需要等待 Rust API 完善或添加解包方法
        // 暂时返回空列表，待 Rust API 完善后再实现
        debugPrint('Rust 搜索返回结果（暂时无法解包）');
        return [];
      } catch (e) {
        debugPrint('Rust 搜索失败：$e');
        // 降级使用数据库搜索
        return await _searchInDatabase(query, bookId: bookId, limit: limit);
      }
    } catch (e) {
      debugPrint('搜索失败：$e');
      return [];
    }
  }

  /// 在数据库中搜索（临时实现
  ///
  /// 注意：此方法需要从 Rust API 获取书籍和章节信息
  /// 未来将使用 Rust 全文搜索替代
  Future<List<SearchHit>> _searchInDatabase(
    String query, {
    String? bookId,
    int limit = 50,
  }) async {
    try {
      // TODO: 从 Rust API 获取书籍和章节信息
      // 当前返回空列表，等待 Rust 搜索 API 完善
      debugPrint('数据库搜索功能待实现，查询：$query');
      return [];
    } catch (e) {
      debugPrint('数据库搜索失败：$e');
      return [];
    }
  }

  /// 删除书籍索引
  Future<void> removeBookIndex(String bookId) async {
    try {
      // 调用 Rust 删除索引函数
      await storage_api.deleteSearchIndex(
        bookId: bookId,
      );
      debugPrint('删除书籍索引完成：bookId=$bookId');
    } catch (e) {
      debugPrint('删除书籍索引失败：bookId=$bookId, error=$e');
    }
  }

  /// 清除所有索引
  Future<void> clearAllIndex() async {
    try {
      // 调用 Rust 清除索引函数
      await search_api.clearAllSearchIndex();
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
