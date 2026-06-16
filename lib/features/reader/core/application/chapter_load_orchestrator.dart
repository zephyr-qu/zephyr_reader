// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
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
        readingMode: _pageState.readingMode.value,
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

      final quickResult = await _runFirstSpine(
        gen,
        request,
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
      );
      if (_isStale(gen) || quickResult == null) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      Logging.info(
        '[Timing] gen=$gen phase=quickPaginate quickPaginate: '
        '${sw.elapsedMilliseconds}ms cumulative',
      );

      Future<int>? fullPaginateFuture;
      if (quickResult.isPartial) {
        _setPhase(gen, ChapterLoadPhase.fullPaginate);
        fullPaginateFuture = _pagination.paginateFull(request.chapterIndex);
      }

      _setPhase(gen, ChapterLoadPhase.awaitingConcurrent);
      final results = await Future.wait([contentFuture, calibFuture]);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      final tConcurrent = sw.elapsedMilliseconds;
      Logging.info(
        '[Timing] gen=$gen phase=awaitingConcurrent '
        '(content+calibration): ${tConcurrent}ms cumulative',
      );

      final content = results[0] as String;
      _applyIfCurrent(gen, () {
        _pagination.calibration.value ??= results[1] as CalibrationData?;
      });

      int total;
      if (quickResult.isPartial) {
        final tBeforePaginate = sw.elapsedMilliseconds;
        total = await fullPaginateFuture!;
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
      _applyIfCurrent(gen, () {
        _loadPhase.value = ChapterLoadPhase.idle;
      });
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
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);

    final firstText = await _contentRepo.loadChapterFirstSpine(
      _pageState.bookId.value,
      request.chapterIndex,
    );
    if (_isStale(gen)) return null;

    final quickResult = await _pagination.paginateQuickFirstScreen(
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
    }

    unawaited(
      preloadAdjacentFirstPages?.call(request.chapterIndex) ?? Future.value(),
    );

    Logging.info('[Timing] gen=$gen phase=firstSpine firstSpine done');
    return quickResult;
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
