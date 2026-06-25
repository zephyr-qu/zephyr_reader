// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent_resolver.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_notice.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节加载显式状态机：分阶段执行 [ChapterLoadRequest] 并防止竞态写信号。
class ChapterLoadOrchestrator {
  static const int _preloadCount = 3;

  ChapterLoadOrchestrator({
    required ReaderRepositoryInterface contentRepo,
    required ReaderConfig config,
    required ChapterViewModel chapterVM,
    required PaginationCoordinator pagination,
    required AsyncSignal<List<Chapter>> chapters,
    required Signal<int> totalPages,
    required Signal<int> pageIndex,
    required Signal<bool> isLoading,
    required Signal<String?> error,
    required Signal<ChapterLoadPhase> loadPhase,
  }) : _contentRepo = contentRepo,
       _config = config,
       _chapterVM = chapterVM,
       _pagination = pagination,
       _chapters = chapters,
       _totalPages = totalPages,
       _pageIndex = pageIndex,
       _isLoading = isLoading,
       _error = error,
       _loadPhase = loadPhase;

  final ReaderRepositoryInterface _contentRepo;
  final ReaderConfig _config;
  final ChapterViewModel _chapterVM;
  final PaginationCoordinator _pagination;
  final AsyncSignal<List<Chapter>> _chapters;
  final Signal<int> _totalPages;
  final Signal<int> _pageIndex;
  final Signal<bool> _isLoading;
  final Signal<String?> _error;
  final Signal<ChapterLoadPhase> _loadPhase;
  int _generation = 0;

  bool _isStale(int gen) => gen != _generation;

  void _setPhase(int gen, ChapterLoadPhase phase) {
    _applyIfCurrent(gen, () {
      _loadPhase.value = phase;
    });
  }

  void _applyIfCurrent(int gen, void Function() action) {
    if (_isStale(gen)) return;
    action();
  }

  Future<void> run(
    ChapterLoadRequest request, {
    Future<void> Function(int chapterIndex, String content)?
    scheduleSearchIndex,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final gen = ++_generation;
    // stagingPromote 路径保留 staging（promote 完成后自身 clear），normalLoad 清除
    final isStagingPromote = request.navigationKind == ChapterNavigationKind.adjacentCrossChapter;
    if (!isStagingPromote) {
      _contentRepo.clearAdjacentStaging();
    }
    final sw = Stopwatch()..start();

    try {
      // 自动推导分页意图（必须在 _runStarting 之前，以得到正确的 preserveContent 默认值）
      final intent = resolveChapterPaginationIntent(
        chapterIndex: request.chapterIndex,
        navigationKind: request.navigationKind,
        repo: _contentRepo,
        pagination: _pagination,
      );
      final effectivePreserveContent = request.preserveContent ??
          shouldPreserveContentForIntent(intent);
      Logging.info(
        '[Timing] gen=$gen intent=$intent preserveContent=$effectivePreserveContent',
      );

      // Scroll/bilingual 模式跳过分页 pipeline，直接加载内容渲染
      if (!_needsPagination(request.readingMode)) {
        await _runScrollOrBilingualMode(
          gen,
          request,
          scheduleSearchIndex: scheduleSearchIndex,
        );
        return;
      }


      await _runStarting(gen, effectivePreserveContent: effectivePreserveContent);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      final chapterPlainFuture = _contentRepo.loadChapterContent(
        _chapterVM.bookId.value,
        request.chapterIndex,
        readingMode: request.readingMode,
      );

      final calibFuture = _pagination.calibration.value != null
          ? Future<CalibrationData?>.value(_pagination.calibration.value)
          : calibrateSafely(
              fontSize: _config.fontSize.value,
              devicePixelRatio: _pagination.devicePixelRatio,
              fontFamily: _pagination.fontFamily,
            );

      final ({int totalPages, bool isPartial})? quickResult;

      quickResult = await _runQuickPaginateForIntent(
        gen,
        intent,
        request,
        calibFuture: calibFuture,
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
      );

      Logging.info(
        '[Timing] gen=$gen phase=quickPaginate quickPaginate: '
        '${sw.elapsedMilliseconds}ms cumulative',
      );

      _setPhase(gen, ChapterLoadPhase.awaitingConcurrent);
      final results = await Future.wait([chapterPlainFuture, calibFuture]);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      final content = results[0] as String;
      _applyIfCurrent(gen, () {
        _pagination.calibration.value ??= results[1] as CalibrationData?;
      });

      final tConcurrent = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] gen=$gen phase=awaitingConcurrent '
        '(content+calibration): ${tConcurrent}ms cumulative',
      );

      int total;
      if (quickResult!.isPartial) {
        _setPhase(gen, ChapterLoadPhase.fullPaginate);
        final fullPaginateFuture = _pagination.expandToFullChapter(
          request.chapterIndex,
        );
        final tBeforePaginate = sw.elapsedMilliseconds;
        total = await fullPaginateFuture;
        if (_isStale(gen)) {
          _setPhase(gen, ChapterLoadPhase.cancelled);
          return;
        }
        Logging.info(
          '[Timing] gen=$gen phase=fullPaginate paginateChapter: '
          '${sw.elapsedMilliseconds - tBeforePaginate}ms '
          '(cumulative: ${sw.elapsedMilliseconds}ms)',
        );
      } else {
        total = quickResult.totalPages;
        Logging.info(
          '[Timing] gen=$gen phase=fullPaginate skipped '
          '(partial covered full content, ${quickResult.totalPages} pages)',
        );
      }

      await _runFinalize(gen, request, content: content, total: total);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      Logging.info(
        '[Timing] gen=$gen phase=completed loadChapter total: '
        '${sw.elapsedMilliseconds}ms',
      );
      await _runComplete(gen, request);
      await _postLoadTasks(
        gen,
        request.chapterIndex,
        content,
        scheduleSearchIndex: scheduleSearchIndex,
      );
      _setPhase(gen, ChapterLoadPhase.completed);
      _applyIfCurrent(gen, () {
        _loadPhase.value = ChapterLoadPhase.idle;
      });
    } catch (e) {
      _applyIfCurrent(gen, () {
        _chapterVM.chapterContent.value = AsyncState.error(e);
        _error.value = AppErrorMapper.humanReadable(e);
        _loadPhase.value = ChapterLoadPhase.failed;
      });
      Logging.error('ChapterLoadOrchestrator.run error', exception: e);
    } finally {
      _applyIfCurrent(gen, () {
        _isLoading.value = false;
      });
    }
  }

  Future<void> _runStarting(int gen, {required bool effectivePreserveContent}) async {
    _setPhase(gen, ChapterLoadPhase.starting);
    if (!effectivePreserveContent) {
      _applyIfCurrent(gen, () {
        _chapterVM.chapterContent.value = AsyncState.loading();
        _isLoading.value = true;
      });
    }
  }

  /// 滚动/双语模式：跳过所有分页 pipeline，直接加载全文渲染。
  ///
  /// 不触发 Rust FFI 分页、校准、首段提取，仅设置章节内容信号。
  Future<void> _runScrollOrBilingualMode(
    int gen,
    ChapterLoadRequest request, {
    required Future<void> Function(int chapterIndex, String content)?
        scheduleSearchIndex,
  }) async {
    _setPhase(gen, ChapterLoadPhase.starting);
    _applyIfCurrent(gen, () {
      _isLoading.value = true;
    });

    final content = await _contentRepo.loadChapterContent(
      _chapterVM.bookId.value,
      request.chapterIndex,
      readingMode: request.readingMode,
    );
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    if (scheduleSearchIndex != null) {
      unawaited(
        Future.microtask(
          () => scheduleSearchIndex(request.chapterIndex, content),
        ),
      );
    }

    _applyIfCurrent(gen, () {
      _chapterVM.chapterContent.value = AsyncState.data(content);
      _chapterVM.chapterIndex.value = request.chapterIndex;
      _chapterVM.currentCharOffset.value =
          request.initialCharOffset.clamp(0, content.length);
      _totalPages.value = 1;
      _pageIndex.value = 0;
      _error.value = null;
      _isLoading.value = false;
      if (request.readingMode == ReadingMode.scroll) {
        _chapterVM.resetScrollDocument(
          content,
          request.chapterIndex,
          richParagraphs: _contentRepo.currentRichParagraphs,
          richRootSpan: _contentRepo.currentRichContent,
          chapterIr: _contentRepo.currentChapterIr,
          chapterFilePath: _contentRepo.currentChapterFilePath,
        );
      }
      if (_contentRepo.consumeEpubRichSkippedNotice()) {
        if (_contentRepo.sessionMode != ChapterPaginationMode.contentBlocks) {
          _chapterVM.readerNotice.value = ReaderNotice.epubRichSkipped;
        }
      }
    });

    _setPhase(gen, ChapterLoadPhase.completed);
    _applyIfCurrent(gen, () {
      _loadPhase.value = ChapterLoadPhase.idle;
    });
  }


  Future<({int totalPages, bool isPartial})?> _runQuickPaginateForIntent(
    int gen,
    ChapterPaginationIntent intent,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) {
    switch (intent) {
      case ChapterPaginationIntent.normalLoad:
        return _runCalibratedPartialPaginate(
          gen,
          request,
          calibFuture: calibFuture,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          paginate: () => _pagination.paginateFirstScreen(request.chapterIndex),
          updateCurrentCharOffset: true,
          fallbackPageIndex: 0,
          logLabel: 'firstSpine',
        );
      case ChapterPaginationIntent.configReload:
        return _runCalibratedPartialPaginate(
          gen,
          request,
          calibFuture: calibFuture,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          paginate: () => _pagination.repaginateCurrentChapter(
            maxChars: PaginationEngine.firstScreenMaxChars,
          ),
          updateCurrentCharOffset: false,
          fallbackPageIndex: _pageIndex.value,
          logLabel: 'configReload',
        );
      case ChapterPaginationIntent.expandOnly:
        return _runExpandOnly(
          gen,
          request,
          calibFuture: calibFuture,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
        );
      case ChapterPaginationIntent.stagingPromoteForward:
        return _runStagingPromote(
          gen,
          request,
          isForward: true,
          calibFuture: calibFuture,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
        );
      case ChapterPaginationIntent.stagingPromoteBackward:
        return _runStagingPromote(
          gen,
          request,
          isForward: false,
          calibFuture: calibFuture,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
        );
    }
  }

  /// normalLoad / configReload 共用：校准 → partial paginate → 按 offset 落页。
  Future<({int totalPages, bool isPartial})?> _runCalibratedPartialPaginate(
    int gen,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
    required Future<({int totalPages, bool isPartial})> Function() paginate,
    required bool updateCurrentCharOffset,
    required int fallbackPageIndex,
    required String logLabel,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);

    final calibResult = await calibFuture;
    if (_isStale(gen)) return null;
    _pagination.calibration.value ??= calibResult;

    final quickResult = await paginate();
    if (_isStale(gen)) return null;

    final descriptors = _contentRepo.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      final resolved = resolveQuickPageForPartial(
        descriptors: descriptors,
        initialCharOffset: request.initialCharOffset,
        isPartial: quickResult.isPartial,
        fallbackPageIndex: fallbackPageIndex,
        resolvePageIndex: _pagination.resolvePageForCharOffset,
      );

      _applyIfCurrent(gen, () {
        _totalPages.value = quickResult.totalPages;
        _chapterVM.chapterIndex.value = request.chapterIndex;
        if (updateCurrentCharOffset) {
          _chapterVM.currentCharOffset.value = resolved.charOffsetForPartial;
        }
        _pageIndex.value = resolved.pageIndex;
        _chapterVM.pendingJumpCharOffset.value = request.initialCharOffset;
        _error.value = null;
        _isLoading.value = false;
      });
      _contentRepo.ensurePageWindow(resolved.pageIndex);
    }

    unawaited(
      preloadAdjacentFirstPages?.call(request.chapterIndex) ?? Future.value(),
    );
    Logging.info('[Timing] gen=$gen phase=firstSpine $logLabel done');
    return quickResult;
  }

  /// expandOnly：同章同 config，handle 已存在则直接 expand to full。
  /// session 不存在时退回 normalLoad 等价路径。
  Future<({int totalPages, bool isPartial})?> _runExpandOnly(
    int gen,
    ChapterLoadRequest request, {
    Future<CalibrationData?>? calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);
    final descriptors = _contentRepo.descriptors;
    if (descriptors == null || descriptors.isEmpty) {
      Logging.info(
        '[Timing] gen=$gen phase=firstSpine expandOnly fell back to firstSpine',
      );
      return _runCalibratedPartialPaginate(
        gen,
        request,
        calibFuture: calibFuture ?? Future.value(_pagination.calibration.value),
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
        paginate: () => _pagination.paginateFirstScreen(request.chapterIndex),
        updateCurrentCharOffset: true,
        fallbackPageIndex: 0,
        logLabel: 'expandOnlyFallback',
      );
    }
    _applyIfCurrent(gen, () {
      _isLoading.value = false;
    });
    return (
      totalPages: descriptors.length,
      isPartial: _contentRepo.sessionIsPartial,
    );
  }

  Future<({int totalPages, bool isPartial})?> _runStagingPromote(
    int gen,
    ChapterLoadRequest request, {
    required bool isForward,
    required Future<CalibrationData?> calibFuture,
    required Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final sw = Stopwatch()..start();
    _setPhase(gen, ChapterLoadPhase.firstSpine);

    // 等待校准完成
    final calibResult = await calibFuture;
    if (_isStale(gen)) return null;
    _pagination.calibration.value ??= calibResult;

    // 释放旧 handle（不清除目标章 streamer cache）
    _contentRepo.disposePagination();
    final result = await _pagination.paginateFirstScreenFromCache(
      request.chapterIndex,
    );
    if (_isStale(gen)) return null;

    final preloadHit = !result.isPartial;

    // 同步写 signals — promote handoff
    final descriptors = _contentRepo.descriptors;
    final pageIndex = isForward
        ? 0
        : ((descriptors?.length ?? 0) - 1).clamp(0, 0x7FFFFFFF);

    _applyIfCurrent(gen, () {
      _totalPages.value = result.totalPages;
      _chapterVM.chapterIndex.value = request.chapterIndex;
      _pageIndex.value = pageIndex;
      _chapterVM.currentCharOffset.value = descriptors != null &&
              pageIndex < descriptors.length
          ? descriptors[pageIndex].startOffset
          : 0;
      _chapterVM.pendingJumpCharOffset.value = null;
      _error.value = null;
      _isLoading.value = false;
    });
    if (pageIndex >= 0) {
      _contentRepo.ensurePageWindow(pageIndex);
    }

    // staging 已消费 → 清除双向旧 staging，预加载新相邻章
    _contentRepo.clearAdjacentStaging();
    unawaited(preloadAdjacentFirstPages?.call(request.chapterIndex));

    final direction = isForward ? 'forward' : 'backward';
    Logging.info(
      '[Timing] gen=$gen phase=stagingPromote direction=$direction chapter_to=${request.chapterIndex} preload_hit=$preloadHit promote_ms=${sw.elapsedMilliseconds}',
    );
    return result;
  }

  Future<void> _runFinalize(
    int gen,
    ChapterLoadRequest request, {
    required String content,
    required int total,
  }) async {
    _setPhase(gen, ChapterLoadPhase.finalizing);

    _applyIfCurrent(gen, () {
      _chapterVM.chapterContent.value = AsyncState.data(content);
    });
    if (_isStale(gen)) return;

    if (request.readingMode == ReadingMode.scroll) {
      _chapterVM.resetScrollDocument(
        content,
        request.chapterIndex,
        richParagraphs: _contentRepo.currentRichParagraphs,
        richRootSpan: _contentRepo.currentRichContent,
        chapterIr: _contentRepo.currentChapterIr,
        chapterFilePath: _contentRepo.currentChapterFilePath,
      );
    }

    final paginationRequired = request.readingMode != ReadingMode.scroll;
    if (paginationRequired && !_pagination.isPaginationValid(total)) {
      _applyIfCurrent(gen, () {
        _error.value = AppErrorMapper.humanReadable(
          Exception('Pagination failed (total=$total)'),
        );
        _loadPhase.value = ChapterLoadPhase.failed;
      });
      return;
    }

    if (!paginationRequired) {
      _applyIfCurrent(gen, () {
        _chapterVM.currentCharOffset.value = request.initialCharOffset.clamp(
          0,
          content.length,
        );
        _error.value = null;
      });
      return;
    }

    final applied = _pagination.applyFullResult(
      total: total,
      initialCharOffset: request.initialCharOffset,
      content: content,
    );
    if (_isStale(gen)) return;

    final descriptors = _contentRepo.descriptors;
    final maxOffset = PaginationEngine.chapterCharOffsetMax(
      sessionMode: _contentRepo.sessionMode,
      descriptors: descriptors,
      phase1PlainContent: content,
    );

    _applyIfCurrent(gen, () {
      _totalPages.value = applied.totalPages;
      _chapterVM.currentCharOffset.value = request.initialCharOffset.clamp(
        0,
        maxOffset,
      );
      _pageIndex.value = applied.pageIndex;
      _chapterVM.pendingJumpCharOffset.value =
          _chapterVM.currentCharOffset.value;
      _error.value = null;
      if (_contentRepo.consumeEpubRichSkippedNotice()) {
        if (_contentRepo.sessionMode != ChapterPaginationMode.contentBlocks) {
          _chapterVM.readerNotice.value = ReaderNotice.epubRichSkipped;
        }
      }
    });
  }

  Future<void> _runComplete(int gen, ChapterLoadRequest request) async {
    if (_isStale(gen)) return;
    if (request.onChapterLoaded != null) {
      await request.onChapterLoaded!();
    }
  }

  Future<void> _postLoadTasks(
    int gen,
    int chapterIndex,
    String content, {
    Future<void> Function(int chapterIndex, String content)?
    scheduleSearchIndex,
  }) async {
    if (_isStale(gen)) return;
    await scheduleSearchIndex?.call(chapterIndex, content);
    if (_isStale(gen)) return;
    unawaited(_prefetchChapters(gen, chapterIndex));
  }

  Future<void> _prefetchChapters(int gen, int centerIndex) async {
    if (_isStale(gen)) return;

    final chapterList = _chapters.value.value ?? [];
    if (chapterList.isEmpty) return;

    final start = (centerIndex - _preloadCount).clamp(
      0,
      chapterList.length - 1,
    );
    final end = (centerIndex + _preloadCount).clamp(0, chapterList.length - 1);

    final indices = <int>[];
    for (int i = start; i <= end; i++) {
      if (i != centerIndex) indices.add(i);
    }
    const batchSize = 2;
    for (int b = 0; b < indices.length; b += batchSize) {
      if (_isStale(gen)) return;
      final batch = indices.skip(b).take(batchSize);
      await Future.wait(
        batch.map(
          (i) => _contentRepo
              .preloadChapter(_chapterVM.bookId.value, i)
              .catchError((_) {}),
        ),
      );
    }
  }

  void resetPhase() {
    ++_generation;
    _loadPhase.value = ChapterLoadPhase.idle;
  }

  /// 判断阅读模式是否需要分页 pipeline。
  ///
  /// 仅 [ReadingMode.pagination] 需要 Rust 分页链路。
  static bool _needsPagination(ReadingMode mode) => needsRustPagination(mode);
}
