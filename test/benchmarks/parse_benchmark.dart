// ignore_for_file: avoid_print

// test/benchmarks/parse_benchmark.dart
//
// 解析性能基准 — 测量 parseBook FFI 调用耗时。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。
// 不设门禁断言，仅记录性能数据。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;

import '../helpers/integration_test_helper.dart';
import '../helpers/test_helper.dart';

const _fixtures = {
  'txt': 'small.txt', // 4.5 KB
  'txt_xl': '活着.txt', // 284 KB
  'epub': '活着.epub', // 185 KB
};

void main() {
  bool ffiOk = false;

  setUpAll(() async {
    if (!isFfiAvailable()) {
      print('[BENCH] FFI not available, skipping benchmark tests');
      return;
    }
    await setupTestStorage(label: 'bench-parse');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  for (final entry in _fixtures.entries) {
    test('bench_parse_${entry.key}', () async {
      if (!ffiOk) return;

      final fixtureName = entry.value;
      final filePath = await copyFixtureFile(fixtureName);

      // warmup
      await core_api.parseBook(filePath: filePath);

      // measure
      final (result, elapsed) = await TestHelper.measure(
        'parseBook($fixtureName)',
        () => core_api.parseBook(filePath: filePath),
      );

      final json = {
        'benchmark': 'parse',
        'fixture': fixtureName,
        'elapsed_ms': elapsed.inMilliseconds,
        'chapters': result.chapters.length,
        'title': result.bookInfo.title,
      };
      print('[RESULT] $json');
    });
  }
}
