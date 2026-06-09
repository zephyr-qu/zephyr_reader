// ignore_for_file: avoid_print

// test/benchmarks/page_turn_benchmark.dart
//
// 翻页性能基准 — 测量连续 getPageContent 调用的延迟分布（median/p99）。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 测量方法: 对同一本书连续翻页 N 次，记录每次 getPageContent 的耗时。
// 输出 median 和 p99 延迟（仅缓存命中路径）。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。
// 不设门禁断言，仅记录性能数据。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

import '../helpers/integration_test_helper.dart';

/// 翻页模拟轮数（覆盖完整章节）
const _pageTurnIterations = 20;

TypesetConfig _readerConfig() {
  return const TypesetConfig(
    pageWidth: 1080,
    pageHeight: 1920,
    fontSize: 18,
    lineSpacing: 1.5,
    letterSpacing: 0,
    paragraphSpacing: 1.0,
    firstLineIndent: 2,
    punctuationSqueeze: true,
    language: LanguageType.auto,
    enableHyphenation: false,
    fontFamily: 'Noto Sans SC',
    calibration: null,
  );
}

void main() {
  bool ffiOk = false;

  setUpAll(() async {
    if (!isFfiAvailable()) {
      print('[BENCH] FFI not available, skipping benchmark tests');
      return;
    }
    await setupTestStorage(label: 'bench-pageturn');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  test('bench_page_turn_活的', () async {
    if (!ffiOk) return;

    // Setup: parse + paginate
    final fixturePath = await copyFixtureFile('活着.txt');
    await core_api.parseBook(filePath: fixturePath);

    final paginateResult = await core_api.paginateChapter(
      filePath: fixturePath,
      chapterIndex: 0,
      config: _readerConfig(),
    );

    final configHash = paginateResult.configHash;
    final totalPages = paginateResult.descriptors.length;
    final turnCount = _pageTurnIterations < totalPages
        ? _pageTurnIterations
        : totalPages;

    // Warmup: 读取前几页以填充缓存
    for (var i = 0; i < 3 && i < totalPages; i++) {
      core_api.getPageContent(
        filePath: fixturePath,
        chapterIndex: 0,
        configHash: configHash,
        pageIndex: i,
      );
    }

    // 测量翻页延迟
    final latencies = <int>[];
    for (var i = 0; i < turnCount; i++) {
      final sw = Stopwatch()..start();
      core_api.getPageContent(
        filePath: fixturePath,
        chapterIndex: 0,
        configHash: configHash,
        pageIndex: i,
      );
      sw.stop();
      latencies.add(sw.elapsedMicroseconds);
    }

    // 排序计算 median / p99
    latencies.sort();
    final median = latencies[latencies.length ~/ 2];
    final p99Index = (latencies.length * 0.99).ceil() - 1;
    final p99 = latencies[p99Index.clamp(0, latencies.length - 1)];

    final json = {
      'benchmark': 'page_turn',
      'book': '活着.txt',
      'pages_measured': turnCount,
      'median_us': median,
      'p99_us': p99,
      'min_us': latencies.first,
      'max_us': latencies.last,
    };
    print('[RESULT] $json');
  });
}
