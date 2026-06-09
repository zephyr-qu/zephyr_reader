// ignore_for_file: avoid_print

// test/benchmarks/reader_tti_benchmark.dart
//
// 书籍打开到首屏渲染（TTI）基准 — 测量 parse + paginate + getPageContent 全链路耗时。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。
// 不设门禁断言，仅记录性能数据。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

import '../helpers/integration_test_helper.dart';
import '../helpers/test_helper.dart';

/// 模拟阅读页使用的默认排版配置（与 ReaderViewModel 保持同步）
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
    await setupTestStorage(label: 'bench-tti');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  test('bench_tti_活的', () async {
    if (!ffiOk) return;

    // (1) 解析书籍
    final fixturePath = await copyFixtureFile('活着.txt');
    final parseResult = await core_api.parseBook(filePath: fixturePath);

    // (2) 分页排版
    final paginateResult = await core_api.paginateChapter(
      filePath: fixturePath,
      chapterIndex: 0,
      config: _readerConfig(),
    );

    // (3) 测量「获取首屏内容」耗时（TTI 核心指标）
    //     模拟阅读页打开完整路径: parseBook → paginateChapter → getPageContent
    //     前两步在真实场景中可能因缓存而在后续打开时跳过，但首开必经。
    final configHash = paginateResult.configHash;
    final pageCount = paginateResult.descriptors.length;
    final (content, elapsed) = await TestHelper.measure<String>(
      'getPageContent(page=0, pages=$pageCount)',
      () async => core_api.getPageContent(
        filePath: fixturePath,
        chapterIndex: 0,
        configHash: configHash,
        pageIndex: 0,
      ),
    );

    final json = {
      'benchmark': 'tti',
      'book': parseResult.bookInfo.title,
      'tti_ms': elapsed.inMilliseconds,
      'total_pages': pageCount,
      'first_page_chars': content.length,
    };
    print('[RESULT] $json');
  });
}
