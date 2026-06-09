// ignore_for_file: avoid_print

// test/benchmarks/search_benchmark.dart
//
// 搜索性能基准 — 测量全文搜索（索引 + 查询）耗时。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。
// 不设门禁断言，仅记录性能数据。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../helpers/integration_test_helper.dart';
import '../helpers/test_helper.dart';

const _searchQueries = ['活着', '福贵', '家珍'];

/// 索引全书所有章节
Future<void> _indexAllChapters(
  String fixturePath,
  String bookId,
  List<Chapter> chapters,
) async {
  for (final ch in chapters) {
    final chapterContent = await core_api.getChapter(
      filePath: fixturePath,
      chapterIndex: ch.chapterIndex.toInt(),
      config: null,
    );
    // 提取文本（freezed 自动生成 when）
    final text = chapterContent.when(
      pages: (pages) => pages.map((p) => p.content).join('\n'),
      raw: (text) => text,
    );
    await search_api.indexChapter(
      bookId: bookId,
      chapterId: ch.id,
      chapterIndex: ch.chapterIndex.toInt(),
      chapterTitle: ch.title,
      content: text,
    );
  }
}

void main() {
  bool ffiOk = false;

  setUpAll(() async {
    if (!isFfiAvailable()) {
      print('[BENCH] FFI not available, skipping benchmark tests');
      return;
    }
    await setupTestStorage(label: 'bench-search');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  test('bench_search_index', () async {
    if (!ffiOk) return;

    final fixturePath = await copyFixtureFile('活着.txt');
    final parseResult = await core_api.parseBook(filePath: fixturePath);
    final bookId = parseResult.bookInfo.bookId;
    final chapters = parseResult.chapters;

    // 初始化搜索引擎
    await search_api.initSearchEngine();

    // 测量索引耗时
    final (_, indexElapsed) = await TestHelper.measure(
      'indexAll(${chapters.length} chapters)',
      () => _indexAllChapters(fixturePath, bookId, chapters),
    );

    final json = {
      'benchmark': 'search_index',
      'book': parseResult.bookInfo.title,
      'chapters': chapters.length,
      'elapsed_ms': indexElapsed.inMilliseconds,
    };
    print('[RESULT] $json');

    // 测量各查询延迟
    for (final query in _searchQueries) {
      // warmup
      await search_api.search(bookId: bookId, query: query, limit: 10);

      final (results, queryElapsed) = await TestHelper.measure(
        'search("$query")',
        () => search_api.search(bookId: bookId, query: query, limit: 10),
      );

      final qJson = {
        'benchmark': 'search_query',
        'query': query,
        'elapsed_ms': queryElapsed.inMilliseconds,
        'results': results.length,
      };
      print('[RESULT] $qJson');
    }
  });
}
