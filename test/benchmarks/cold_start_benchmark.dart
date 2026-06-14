// ignore_for_file: avoid_print

// test/benchmarks/cold_start_benchmark.dart
//
// 冷启动 + 大章节加载性能基准 — 测量完整阅读引擎管线的耗时分布。
//
// 模拟用户打开一本大书的流程:
//   1. parseBook（解析书籍）
//   2. paginateChapterPartial（部分分页，最多前 50K 字符）
//   3. 检查 isPartial 决定是否 paginateChapter（完整分页）
//   4. getPageContent(0)（获取首屏内容 = TTI）
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

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
    await setupTestStorage(label: 'bench-coldstart');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  /// 大章节测试：活着.txt (284KB, 通常 >50K 字符/章)
  test('bench_coldstart_large_chapter', () async {
    if (!ffiOk) return;

    final fixturePath = await copyFixtureFile('活着.txt');

    // ── 1. Parse ──
    final sw1 = Stopwatch()..start();
    final parseResult = await core_api.parseBook(filePath: fixturePath);
    final parseMs = sw1.elapsedMilliseconds;

    // ── 2. 部分分页（模拟 loadChapter 第一阶段）──
    final sw2 = Stopwatch()..start();
    final partialResult = await core_api.paginateChapter(
      filePath: fixturePath,
      chapterIndex: 0,
      config: _readerConfig(),
      maxChars: BigInt.from(50000),
    );
    final partialMs = sw2.elapsedMilliseconds;
    final partialPages = partialResult.descriptors.length;

    // ── 3. 仅在需要时完整分页 ──
    PaginateResult? fullResult;
    int? fullMs;
    if (partialResult.isPartial) {
      final sw3 = Stopwatch()..start();
      fullResult = await core_api.paginateChapter(
        filePath: fixturePath,
        chapterIndex: 0,
        config: _readerConfig(),
      );
      fullMs = sw3.elapsedMilliseconds;
    }

    final totalPages = fullResult?.descriptors.length ?? partialPages;

    // ── 4. 获取首屏内容（TTI） ──
    final configHash = (fullResult ?? partialResult).configHash;
    final sw4 = Stopwatch()..start();
    final content = core_api.getPageContent(
      filePath: fixturePath,
      chapterIndex: 0,
      configHash: configHash,
      pageIndex: 0,
    );
    final ttiMs = sw4.elapsedMilliseconds;

    final totalMs = parseMs + partialMs + (fullMs ?? 0) + ttiMs;
    final json = {
      'benchmark': 'coldstart',
      'book': parseResult.bookInfo.title,
      'chapters': parseResult.chapters.length,
      'parse_ms': parseMs,
      'partial_ms': partialMs,
      'partial_pages': partialPages,
      'is_partial': partialResult.isPartial,
      'full_ms': fullMs,
      'total_pages': totalPages,
      'tti_ms': ttiMs,
      'total_ms': totalMs,
      'first_page_chars': content.length,
    };
    print('[RESULT] $json');
  });

  /// 小章节测试：small.txt (4.5KB, 远 <50K 字符)
  /// 用于验证短路逻辑 — full paginate 应被跳过
  test('bench_coldstart_small_chapter', () async {
    if (!ffiOk) return;

    final fixturePath = await copyFixtureFile('small.txt');
    await core_api.parseBook(filePath: fixturePath); // warmup

    // ── 部分分页（小章节应自动降级为完整分页）──
    final sw = Stopwatch()..start();
    final partialResult = await core_api.paginateChapter(
      filePath: fixturePath,
      chapterIndex: 0,
      config: _readerConfig(),
      maxChars: BigInt.from(50000),
    );

    final json = {
      'benchmark': 'coldstart',
      'book': 'small.txt',
      'partial_ms': sw.elapsedMilliseconds,
      'partial_pages': partialResult.descriptors.length,
      'is_partial': partialResult.isPartial,
      'note': partialResult.isPartial
          ? 'need_full_paginate'
          : 'SHORT_CIRCUIT: partial returned full content',
    };
    print('[RESULT] $json');
  });
}
