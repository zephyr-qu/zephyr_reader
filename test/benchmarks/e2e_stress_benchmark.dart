// ignore_for_file: avoid_print

// test/benchmarks/e2e_stress_benchmark.dart
//
// 端到端压测 — 使用大文件 (large.txt 51.2MB) 测试 parse + paginate + page_turn。
//
// 前提: Rust FFI 已通过 RustLib.init() 初始化。
// 仅在宿主平台（Windows/macOS/Linux）上运行。
//
// 输出格式: 每行一个 JSON 对象，方便 CI 解析汇总。
// 不设门禁断言，仅记录性能数据。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

import '../helpers/integration_test_helper.dart';
import '../helpers/test_helper.dart';

const String _largeFile = 'large.txt'; // 51.2 MB
const String _mediumFile = '活着.txt'; // 284 KB
const String _epubMedium = 'medium.epub'; // 1.2 MB

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

/// 打印 JSON 结果行
void emitResult(Map<String, Object?> data) {
  print('[RESULT] ${jsonEncode(data)}');
}

void main() {
  bool ffiOk = false;
  final config = _readerConfig();

  setUpAll(() async {
    if (!isFfiAvailable()) {
      print('[BENCH] FFI not available, skipping benchmark tests');
      return;
    }
    // 使用独立标签以避免测试间存储污染
    await setupTestStorage(label: 'bench-e2e-stress');
    ffiOk = true;
  });

  tearDownAll(() async {
    if (!ffiOk) return;
    await teardownTestStorage();
  });

  // ════════════════════════════════════════════════════════
  // 1. 大文件完整生命周期压测
  // ════════════════════════════════════════════════════════
  group('1. large_file_lifecycle', () {
    test('parse_51MB_file', () async {
      if (!ffiOk) return;

      final filePath = await copyFixtureFile(_largeFile);
      final fileSize = await File(filePath).length();

      final (result, elapsed) = await TestHelper.measure(
        'parseBook(large.txt)',
        () => core_api.parseBook(filePath: filePath),
      );

      emitResult({
        'test': 'large_file',
        'phase': 'parse_book',
        'file_size_bytes': fileSize,
        'elapsed_ms': elapsed.inMilliseconds,
        'chapters': result.chapters.length,
        'title': result.bookInfo.title,
      });
    });

    test('paginate_large_chapter', () async {
      if (!ffiOk) return;

      // 解析后获取章节 0 的分页耗时
      final filePath = await copyFixtureFile(_largeFile);

      // 先解析
      await core_api.parseBook(filePath: filePath);

      // 测量首次分页（含 Provider 创建 + SQLite 查章节边界）
      final (firstResult, firstElapsed) = await TestHelper.measure(
        'paginateChapter(large.txt, ch0)',
        () => core_api.paginateChapter(
          filePath: filePath,
          chapterIndex: 0,
          config: config,
        ),
      );

      emitResult({
        'test': 'large_file',
        'phase': 'first_paginate_chapter',
        'elapsed_ms': firstElapsed.inMilliseconds,
        'descriptors': firstResult.descriptors.length,
        'config_hash': firstResult.configHash,
      });

      // 测量缓存命中后二次分页
      final (cachedResult, cachedElapsed) = await TestHelper.measure(
        'paginateChapter(large.txt, ch0, cached)',
        () => core_api.paginateChapter(
          filePath: filePath,
          chapterIndex: 0,
          config: config,
        ),
      );

      emitResult({
        'test': 'large_file',
        'phase': 'cached_paginate_chapter',
        'elapsed_ms': cachedElapsed.inMilliseconds,
        'descriptors': cachedResult.descriptors.length,
        'config_hash': cachedResult.configHash,
      });

      // 使用 paginateAllContent 替代（全量布局，返回完整 PageContent）
      final (allContentResult, allContentElapsed) = await TestHelper.measure(
        'paginateAllContent(large.txt, ch0)',
        () => core_api.paginateAllContent(
          filePath: filePath,
          chapterIndex: 0,
          config: config,
        ),
      );

      emitResult({
        'test': 'large_file',
        'phase': 'paginate_all_content',
        'elapsed_ms': allContentElapsed.inMilliseconds,
        'page_count': allContentResult.length,
      });

      // 测量后续多次 getPageContent（翻页延迟分布）
      final descriptorCount = firstResult.descriptors.length;
      final pageCount = descriptorCount > 100 ? 100 : descriptorCount;
      final configHash = firstResult.configHash;

      final stopwatch = Stopwatch()..start();
      final latencies = <int>[];
      for (int i = 0; i < pageCount; i++) {
        final sw = Stopwatch()..start();
        core_api.getPageContent(
          filePath: filePath,
          chapterIndex: 0,
          configHash: configHash,
          pageIndex: i,
        );
        sw.stop();
        latencies.add(sw.elapsedMicroseconds);
      }
      stopwatch.stop();

      latencies.sort();
      final totalMicros = latencies.fold<int>(0, (a, b) => a + b);
      emitResult({
        'test': 'large_file',
        'phase': 'page_turn',
        'pages_sampled': pageCount,
        'total_ms': stopwatch.elapsedMilliseconds,
        'avg_us': totalMicros ~/ pageCount,
        'p50_us': latencies[pageCount ~/ 2],
        'p95_us': latencies[((pageCount * 0.95).ceil()) - 1],
        'p99_us': latencies[((pageCount * 0.99).ceil()) - 1],
        'min_us': latencies.first,
        'max_us': latencies.last,
      });
    });
  });

  // ════════════════════════════════════════════════════════
  // 2. 批量导入压测
  // ════════════════════════════════════════════════════════
  group('2. batch_import', () {
    Future<void> batchImport(int count, String fixtureName) async {
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < count; i++) {
        final path = await copyFixtureFile(fixtureName);
        await core_api.parseBook(filePath: path);
      }
      stopwatch.stop();
      emitResult({
        'test': 'batch_import',
        'fixture': fixtureName,
        'count': count,
        'total_ms': stopwatch.elapsedMilliseconds,
        'avg_ms': stopwatch.elapsedMilliseconds / count,
      });
    }

    test('batch_5x_活着.txt', () async {
      if (!ffiOk) return;
      await batchImport(5, _mediumFile);
    });

    test('batch_20x_活着.txt', () async {
      if (!ffiOk) return;
      await batchImport(20, _mediumFile);
    });

    test('batch_5x_medium.epub', () async {
      if (!ffiOk) return;
      await batchImport(5, _epubMedium);
    });
  });

  // ════════════════════════════════════════════════════════
  // 3. 多章节排版压测
  // ════════════════════════════════════════════════════════
  group('3. multi_chapter_pagination', () {
    test('多章节 paginate (活着.txt)', () async {
      if (!ffiOk) return;

      final filePath = await copyFixtureFile(_mediumFile);
      final parseResult =
          await core_api.parseBook(filePath: filePath);
      final chapterCount = parseResult.chapters.length;

      emitResult({
        'test': 'multi_chapter',
        'phase': 'parse',
        'chapters': chapterCount,
      });

      // 逐个分页每个章节
      final chapterLatencies = <int>[];
      int totalPages = 0;
      for (int i = 0; i < chapterCount; i++) {
        final (paginateResult, elapsed) = await TestHelper.measure(
          'paginateChapter(ch$i)',
          () => core_api.paginateChapter(
            filePath: filePath,
            chapterIndex: i,
            config: config,
          ),
        );
        chapterLatencies.add(elapsed.inMilliseconds);
        totalPages += paginateResult.descriptors.length;
      }

      chapterLatencies.sort();
      final avgMs = chapterLatencies.fold<int>(0, (a, b) => a + b) /
          chapterLatencies.length;
      emitResult({
        'test': 'multi_chapter',
        'phase': 'paginate_all',
        'chapter_count': chapterCount,
        'total_pages': totalPages,
        'avg_ms': avgMs,
        'p50_ms': chapterLatencies[chapterCount ~/ 2],
        'p95_ms': chapterLatencies[((chapterCount * 0.95).ceil()) - 1],
        'max_ms': chapterLatencies.last,
      });
    });
  });

  // ════════════════════════════════════════════════════════
  // 4. 配置变更后重新排版压测
  // ════════════════════════════════════════════════════════
  group('4. config_change_retypeset', () {
    test('不同 fontSize 下重排版耗时', () async {
      if (!ffiOk) return;

      final filePath = await copyFixtureFile(_mediumFile);
      await core_api.parseBook(filePath: filePath);

      final fontSizes = [12, 16, 20, 24, 32];
      final latencies = <int>[];

      for (final size in fontSizes) {
        final variedConfig = TypesetConfig(
          pageWidth: 1080,
          pageHeight: 1920,
          fontSize: size,
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

        final (result, elapsed) = await TestHelper.measure(
          'paginate(fontSize=$size)',
          () => core_api.paginateChapter(
            filePath: filePath,
            chapterIndex: 0,
            config: variedConfig,
          ),
        );

        latencies.add(elapsed.inMilliseconds);
        emitResult({
          'test': 'config_change',
          'font_size': size,
          'elapsed_ms': elapsed.inMilliseconds,
          'pages': result.descriptors.length,
        });
      }
    });
  });
}
