// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节加载显式状态机：分阶段执行 [ChapterLoadRequest] 并防止竞态写信号。
class ChapterLoadOrchestrator {
  static const int _preloadCount = 3;

  ChapterLoadOrchestrator({
    required ReaderRepositoryInterface contentRepo,
    required ReaderConfig config,
    required ReaderPageState pageState,
    required PaginationCoordinator pagination,
    required AsyncSignal<List<Chapter>> chapters,
    required Signal<int> totalPages,
    required Signal<int> pageIndex,
    required Signal<bool> isLoading,
    required Signal<String?> error,
    required Signal<ChapterLoadPhase> loadPhase,
  }) : _contentRepo = contentRepo,
       _config = config,
       _pageState = pageState,
       _pagination = pagination,
       _chapters = chapters,
       _totalPages = totalPages,
       _pageIndex = pageIndex,
       _isLoading = isLoading,
       _error = error,
       _loadPhase = loadPhase;

  final ReaderRepositoryInterface _contentRepo;
  final ReaderConfig _config;
  final ReaderPageState _pageState;
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
    Future<void> Function(int chapterIndex, String content)? scheduleSearchIndex,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final gen = ++_generation;
    final sw = Stopwatch()..start();

    try {
      await _runStarting(gen, request);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      final contentFuture = _contentRepo.loadChapterContent(
        _pageState.bookId.value,
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

      unawaited(
        contentFuture
            .then(
              (content) => _postLoadTasks(
                gen,
                request.chapterIndex,
                content,
                scheduleSearchIndex: scheduleSearchIndex,
              ),
            )
            .catchError((_) {}),
      );

      final ({int totalPages, bool isPartial})? quickResult;

      switch (request.intent) {
        case ChapterPaginationIntent.normalLoad:
          quickResult = await _runFirstSpine(
            gen,
            request,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
        case ChapterPaginationIntent.configReload:
          if (_contentRepo.sessionConfigHash == null) {
            // 首屏未完成，handle 不存在 → 退回 normalLoad
            Logging.info(
              '[Timing] gen=$gen phase=firstSpine configReload fell back to firstSpine '
              '(no session yet)',
            );
            quickResult = await _runFirstSpine(
              gen,
              request,
              calibFuture: calibFuture,
              preloadAdjacentFirstPages: preloadAdjacentFirstPages,
            );
          } else {
            quickResult = await _runConfigReload(
              gen,
              request,
              calibFuture: calibFuture,
            );
          }
        case ChapterPaginationIntent.expandOnly:
          quickResult = await _runExpandOnly(
            gen,
            request,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
      }

      if (_isStale(gen) || quickResult == null) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      Logging.info(
        '[Timing] gen=$gen phase=quickPaginate quickPaginate: '
        '${sw.elapsedMilliseconds}ms cumulative',
      );

      _setPhase(gen, ChapterLoadPhase.awaitingConcurrent);
      final results = await Future.wait([contentFuture, calibFuture]);
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
      if (quickResult.isPartial) {
        _setPhase(gen, ChapterLoadPhase.fullPaginate);
        final fullPaginateFuture =
            _pagination.expandToFullChapter(request.chapterIndex);
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
      _setPhase(gen, ChapterLoadPhase.completed);
      _applyIfCurrent(gen, () {
        _loadPhase.value = ChapterLoadPhase.idle;
      });
    } catch (e) {
      _applyIfCurrent(gen, () {
        _pageState.chapterContent.value = AsyncState.error(e);
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

  Future<void> _runStarting(int gen, ChapterLoadRequest request) async {
    _setPhase(gen, ChapterLoadPhase.starting);
    if (!request.preserveContent) {
      _applyIfCurrent(gen, () {
        _pageState.chapterContent.value = AsyncState.loading();
        _isLoading.value = true;
      });
    }
  }

  Future<({int totalPages, bool isPartial})?> _runFirstSpine(
    int gen,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);

    final firstText = await _contentRepo.loadChapterFirstSpine(
      _pageState.bookId.value,
      request.chapterIndex,
    );
    if (_isStale(gen)) return null;

    // 等待校准完成，并把结果写入 calibration.value，使后续 buildPaginationParams
    // 能读到非 null 的 CharWidthTable。session 内的 config 由 beginPaginate 当下构建，
    // 后续 paginate_session_full 也会沿用带校准的存储 config。
    final calibResult = await calibFuture;
    if (_isStale(gen)) return null;
    _pagination.calibration.value ??= calibResult;

    final quickResult = await _pagination.paginateFirstScreen(
      request.chapterIndex,
    );
    if (_isStale(gen)) return null;

    final descriptors = _contentRepo.descriptors;
    if (descriptors != null && descriptors.isNotEmpty) {
      final charOffset = request.initialCharOffset.clamp(0, firstText.length);
      final resolvedPage = PaginationEngine.resolvePageIndexForOffset(
        descriptors,
        charOffset,
      );

      _applyIfCurrent(gen, () {
        _pageState.chapterContent.value = AsyncState.data(firstText);
        _totalPages.value = quickResult.totalPages;
        _pageState.chapterIndex.value = request.chapterIndex;
        _pageState.currentCharOffset.value = charOffset;
        _pageIndex.value = resolvedPage;
        _pageState.pendingJumpCharOffset.value = charOffset;
        _error.value = null;
        _isLoading.value = false;
      });
      _contentRepo.ensurePageWindow(resolvedPage);
    }

    unawaited(
      preloadAdjacentFirstPages?.call(request.chapterIndex) ?? Future.value(),
    );

    Logging.info('[Timing] gen=$gen phase=firstSpine firstSpine done');
    return quickResult;
  }

  /// configReload：等 calib 完成后用新 config in-place repaginate。
  /// 不 dispose handle，不重走 firstSpine。
  Future<({int totalPages, bool isPartial})?> _runConfigReload(
    int gen,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);
    final calibResult = await calibFuture;
    if (_isStale(gen)) return null;
    _pagination.calibration.value ??= calibResult;

    final quickResult = await _pagination.repaginateCurrentChapter(
      maxChars: PaginationEngine.firstScreenMaxChars,
    );
    if (_isStale(gen)) return null;

    // 按 request.initialCharOffset + 新 descriptors 重算 pageIndex
    // （request 是统一入口，currentCharOffset 可能是 stale 值）
    final descriptors = _contentRepo.descriptors;
    final charOffset = request.initialCharOffset;
    int resolvedPage = _pageIndex.value;
    if (descriptors != null && descriptors.isNotEmpty) {
      final newResolved = PaginationEngine.resolvePageIndexForOffset(
        descriptors,
        charOffset,
      );
      if (newResolved >= 0) resolvedPage = newResolved;
    }

    _applyIfCurrent(gen, () {
      _totalPages.value = quickResult.totalPages;
      _pageState.chapterIndex.value = request.chapterIndex;
      _pageIndex.value = resolvedPage;
      _pageState.pendingJumpCharOffset.value = charOffset;
      _error.value = null;
      _isLoading.value = false;
    });
    if (resolvedPage >= 0) {
      _contentRepo.ensurePageWindow(resolvedPage);
    }
    Logging.info('[Timing] gen=$gen phase=firstSpine configReload done');
    return quickResult;
  }

  /// expandOnly：同章同 config，handle 已存在则直接 expand to full。
  /// session 不存在时退回 [firstSpine] 流程。
  Future<({int totalPages, bool isPartial})?> _runExpandOnly(
    int gen,
    ChapterLoadRequest request, {
    Future<CalibrationData?>? calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);
    final descriptors = _contentRepo.descriptors;
    if (descriptors == null || descriptors.isEmpty) {
      // session 不存在 → 退回 firstSpine（normalLoad 等价路径）
      Logging.info(
        '[Timing] gen=$gen phase=firstSpine expandOnly fell back to firstSpine',
      );
      return _runFirstSpine(
        gen,
        request,
        calibFuture: calibFuture ?? Future.value(_pagination.calibration.value),
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
      );
    }
    _applyIfCurrent(gen, () {
      _isLoading.value = false;
    });
    return (
      totalPages: descriptors.length,
      isPartial: true, // 强制 full expand
    );
  }


  Future<void> _runFinalize(
    int gen,
    ChapterLoadRequest request, {
    required String content,
    required int total,
  }) async {
    _setPhase(gen, ChapterLoadPhase.finalizing);

    _applyIfCurrent(gen, () {
      _pageState.chapterContent.value = AsyncState.data(content);
    });
    if (_isStale(gen)) return;

    if (!_pagination.isPaginationValid(total)) {
      final fallback = await _pagination.fallbackToCalculatePages(
        chapterIndex: request.chapterIndex,
        initialCharOffset: request.initialCharOffset,
        content: content,
      );
      if (_isStale(gen)) return;

      _applyIfCurrent(gen, () {
        _totalPages.value = fallback.totalPages;
        _pageState.currentCharOffset.value = request.initialCharOffset.clamp(
          0,
          content.length,
        );
        _pageIndex.value = fallback.pageIndex;
        _pageState.pendingJumpCharOffset.value =
            _pageState.currentCharOffset.value;
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

    _applyIfCurrent(gen, () {
      _totalPages.value = applied.totalPages;
      _pageState.currentCharOffset.value = request.initialCharOffset.clamp(
        0,
        content.length,
      );
      _pageIndex.value = applied.pageIndex;
      _pageState.pendingJumpCharOffset.value =
          _pageState.currentCharOffset.value;
      _error.value = null;
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
    Future<void> Function(int chapterIndex, String content)? scheduleSearchIndex,
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
              .preloadChapter(_pageState.bookId.value, i)
              .catchError((_) {}),
        ),
      );
    }
  }

  void resetPhase() {
    ++_generation;
    _loadPhase.value = ChapterLoadPhase.idle;
  }
}
