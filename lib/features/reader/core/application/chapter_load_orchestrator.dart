// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
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
      final intent = resolveIntent(
        chapterIndex: request.chapterIndex,
        navigationKind: request.navigationKind,
        repo: _contentRepo,
        pagination: _pagination,
      );
      final effectivePreserveContent = request.preserveContent ??
          (intent != ChapterPaginationIntent.normalLoad);
      Logging.info(
        '[Timing] gen=$gen intent=$intent preserveContent=$effectivePreserveContent',
      );

      await _runStarting(gen, effectivePreserveContent: effectivePreserveContent);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      final contentFuture = _contentRepo.loadChapterContent(
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

      switch (intent) {
        case ChapterPaginationIntent.normalLoad:
          quickResult = await _runFirstSpine(
            gen,
            request,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
        case ChapterPaginationIntent.configReload:
          quickResult = await _runConfigReload(
            gen,
            request,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
        case ChapterPaginationIntent.expandOnly:
          quickResult = await _runExpandOnly(
            gen,
            request,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
        case ChapterPaginationIntent.stagingPromoteForward:
          quickResult = await _runStagingPromote(
            gen,
            request,
            isForward: true,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
        case ChapterPaginationIntent.stagingPromoteBackward:
          quickResult = await _runStagingPromote(
            gen,
            request,
            isForward: false,
            calibFuture: calibFuture,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
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

  Future<({int totalPages, bool isPartial})?> _runFirstSpine(
    int gen,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    _setPhase(gen, ChapterLoadPhase.firstSpine);

    final firstText = await _contentRepo.loadChapterFirstSpine(
      _chapterVM.bookId.value,
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
        _chapterVM.chapterContent.value = AsyncState.data(firstText);
        _totalPages.value = quickResult.totalPages;
        _chapterVM.chapterIndex.value = request.chapterIndex;
        _chapterVM.currentCharOffset.value = charOffset;
        _pageIndex.value = resolvedPage;
        _chapterVM.pendingJumpCharOffset.value = charOffset;
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
  Future<({int totalPages, bool isPartial})?> _runConfigReload(
    int gen,
    ChapterLoadRequest request, {
    required Future<CalibrationData?> calibFuture,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
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
      _chapterVM.chapterIndex.value = request.chapterIndex;
      _pageIndex.value = resolvedPage;
      _chapterVM.pendingJumpCharOffset.value = charOffset;
      _error.value = null;
      _isLoading.value = false;
    });
    if (resolvedPage >= 0) {
      _contentRepo.ensurePageWindow(resolvedPage);
    }
    Logging.info('[Timing] gen=$gen phase=firstSpine configReload done');
    unawaited(
      preloadAdjacentFirstPages?.call(request.chapterIndex) ?? Future.value(),
    );
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

    Logging.info('[Timing] gen=$gen phase=firstSpine stagingPromote done');
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

    if (!_pagination.isPaginationValid(total)) {
      _applyIfCurrent(gen, () {
        _error.value = AppErrorMapper.humanReadable(
          Exception('Pagination failed (total=$total)'),
        );
        _loadPhase.value = ChapterLoadPhase.failed;
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
      _chapterVM.currentCharOffset.value = request.initialCharOffset.clamp(
        0,
        content.length,
      );
      _pageIndex.value = applied.pageIndex;
      _chapterVM.pendingJumpCharOffset.value =
          _chapterVM.currentCharOffset.value;
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

  /// 根据当前 session 状态、导航类型与 staging 自动推导分页意图。
  static ChapterPaginationIntent resolveIntent({
    required int chapterIndex,
    required ChapterNavigationKind navigationKind,
    required ReaderRepositoryInterface repo,
    required PaginationCoordinator pagination,
  }) {
    // stagingPromote 路径优先检查
    if (navigationKind == ChapterNavigationKind.adjacentCrossChapter) {
      // 先检查 staging 存在且 chapterIndex 匹配，再计算 configHash（避免 FFI 调用）
      final nextStaging = repo.nextChapterStaging;
      if (nextStaging != null && nextStaging.chapterIndex == chapterIndex) {
        final currentHash = pagination.computeConfigHash();
        if (nextStaging.configHash == currentHash) {
          return ChapterPaginationIntent.stagingPromoteForward;
        }
      }
      // 后退 staging（prevChapterStaging 末页）
      final prevStaging = repo.prevChapterStaging;
      if (prevStaging != null && prevStaging.chapterIndex == chapterIndex) {
        final currentHash = pagination.computeConfigHash();
        if (prevStaging.configHash == currentHash) {
          return ChapterPaginationIntent.stagingPromoteBackward;
        }
      }
    }

    final hash = repo.sessionConfigHash;
    final descriptors = repo.descriptors;
    final sessionChapterIndex = repo.sessionChapterIndex;

    final sessionValid = hash != null &&
        (descriptors?.isNotEmpty == true) &&
        sessionChapterIndex == chapterIndex;

    if (!sessionValid) return ChapterPaginationIntent.normalLoad;

    final currentHash = pagination.computeConfigHash();
    if (currentHash != hash) return ChapterPaginationIntent.configReload;

    return ChapterPaginationIntent.expandOnly;
  }
}
