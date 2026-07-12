// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/scheduler.dart';
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
import 'package:zephyr_reader/features/reader/data/layout_calibration_store.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/spike/flutter_pagination_spike_flag.dart';
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
    final isStagingPromote =
        request.navigationKind == ChapterNavigationKind.adjacentCrossChapter;
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
      final effectivePreserveContent =
          request.preserveContent ?? shouldPreserveContentForIntent(intent);
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

      // 方案三：Flutter 精确分页旁路（默认关）
      if (kFlutterPaginationSpike) {
        if (intent == ChapterPaginationIntent.stagingPromoteForward ||
            intent == ChapterPaginationIntent.stagingPromoteBackward) {
          await _runFlutterStagingPromote(
            gen,
            request,
            isForward: intent == ChapterPaginationIntent.stagingPromoteForward,
            scheduleSearchIndex: scheduleSearchIndex,
            preloadAdjacentFirstPages: preloadAdjacentFirstPages,
          );
          return;
        }
        await _runFlutterPaginationSpike(
          gen,
          request,
          scheduleSearchIndex: scheduleSearchIndex,
          preloadAdjacentFirstPages: preloadAdjacentFirstPages,
        );
        return;
      }

      await _runStarting(
        gen,
        effectivePreserveContent: effectivePreserveContent,
      );
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      if (!isStagingPromote) {
        Logging.info(
          '[FirstLoad] gen=$gen starting pagination intent=$intent chapter=${request.chapterIndex}',
        );
      }

      // Phase 6: 分页前预加载全文并提取 ICU 行断点索引。
      // 使首次分页即走精确的 paginate_from_line_breaks 路径，
      // 而非先贪心后修正。
      final chapterContent = isStagingPromote
          ? ''
          : await _loadAndMeasureContent(gen, request);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      // 文本已预加载，后续不再重复 loadChapterContent
      final chapterPlainFuture = Future<String>.value(chapterContent);

      final calibFuture = resolveLayoutCalibration(
        params: _typesetMeasureParams(),
        prefs: getIt<PreferencesService>(),
      );

      final ({int totalPages, bool isPartial})? quickResult;

      quickResult = await _runQuickPaginateForIntent(
        gen,
        intent,
        request,
        calibFuture: calibFuture,
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
      );
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }

      // stagingPromote 路径：_runStagingPromote 已设置所有信号，跳过冗余后继处理。
      if (intent == ChapterPaginationIntent.stagingPromoteForward ||
          intent == ChapterPaginationIntent.stagingPromoteBackward) {
        Logging.info(
          '[ChapterTransition] gen=$gen promote done ${sw.elapsedMilliseconds}ms '
          'chapter=${request.chapterIndex} pages=${quickResult?.totalPages ?? "?"}',
        );
        _setPhase(gen, ChapterLoadPhase.completed);
        _applyIfCurrent(gen, () {
          _loadPhase.value = ChapterLoadPhase.idle;
        });
        return;
      }

      Logging.info(
        '[Timing] gen=$gen phase=quickPaginate quickPaginate: '
        '${sw.elapsedMilliseconds}ms cumulative',
      );

      // 仅 initial load / config 变更时回传 metrics；expandOnly 校准已稳定，
      // 重复回传会导致章内翻页时重分页 → 已渲染页面排版跳变（Bug #2）。
      final shouldBackfeed =
          intent == ChapterPaginationIntent.normalLoad ||
          intent == ChapterPaginationIntent.configReload;
      final backfeedFuture = shouldBackfeed
          ? _captureMetricsBackfeed(gen, _pageIndex.value)
          : Future<CalibrationData?>.value(null);

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

      final refinedCalibration = await backfeedFuture;

      // Bug B fix: refinedCalibration 暂不更新到 calibration.value，
      // 避免 expandToFullChapter / repaginate 使用不同校准改变已显示页边界。
      // 延后到所有分页操作完成后更新（仅用于后续新 session）。
      // 见 issue/KNOWN_POSTPHASE4_BUGS.md Bug B

      int total;
      final bool isNormalLoad = intent == ChapterPaginationIntent.normalLoad;
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
        _syncPaginationSignalsAfterRepaginate(
          gen,
          request,
          totalPages: total,
          content: content,
        );
        Logging.info(
          '[Timing] gen=$gen phase=fullPaginate paginateChapter: '
          '${sw.elapsedMilliseconds - tBeforePaginate}ms '
          '(cumulative: ${sw.elapsedMilliseconds}ms)',
        );
      } else {
        total = quickResult.totalPages;
        if (refinedCalibration != null && !isNormalLoad) {
          // configReload: 用户已预期视觉变化，inline repaginate
          final repaginated = await _pagination.repaginateAfterMetricsBackfeed(
            maxChars: null,
          );
          if (_isStale(gen)) {
            _setPhase(gen, ChapterLoadPhase.cancelled);
            return;
          }
          total = repaginated.totalPages;
          _syncPaginationSignalsAfterRepaginate(
            gen,
            request,
            totalPages: total,
            content: content,
          );
          Logging.info(
            '[Timing] gen=$gen phase=metricsBackfeed repaginate: '
            'pages=$total',
          );
        } else if (refinedCalibration != null && isNormalLoad) {
          // Bug B fix: normalLoad 不 repaginate，避免排版跳变。
          // 回传校准值已推迟到所有分页操作后更新 calibration.value 信号，
          // 供后续新 session（下一章 / configReload）使用。
          Logging.info(
            '[Timing] gen=$gen phase=metricsBackfeed deferred (normalLoad)',
          );
        }
        Logging.info(
          '[Timing] gen=$gen phase=fullPaginate skipped '
          '(partial covered full content, ${quickResult.totalPages} pages)',
        );
      }

      // 所有分页操作完成后，更新校准信号并写入本地缓存供后续 session 使用
      if (refinedCalibration != null && !_isStale(gen)) {
        _pagination.calibration.value = refinedCalibration;
        final params = _typesetMeasureParams();
        unawaited(
          LayoutCalibrationStore.save(
            getIt<PreferencesService>(),
            LayoutCalibrationStore.cacheKey(params),
            refinedCalibration,
          ),
        );
      }

      Logging.info(
        '[FirstLoad] gen=$gen finalize contentLen=${content.length} total=$total isPartial=${quickResult.isPartial}'
        ' cumulative=${sw.elapsedMilliseconds}ms',
      );

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

      // Phase 6: 分页模式下预计算行断点并存入 Rust 缓存
      if (_needsPagination(request.readingMode)) {
        unawaited(_pagination.storeLineBreaks(content));
      }

      _setPhase(gen, ChapterLoadPhase.completed);
      _applyIfCurrent(gen, () {
        _loadPhase.value = ChapterLoadPhase.idle;
      });
    } catch (e) {
      _applyIfCurrent(gen, () {
        // P3 (Bug A) 修复：stagingPromote 已成功设置信号后，
        // 后续错误（如 clearAdjacentStaging）不应覆盖已可见的内容。
        // 非 stagingPromote 路径正常显示错误。
        if (isStagingPromote && _chapterVM.chapterContent.value.value != null) {
          Logging.warning(
            '[ChapterLoad] stagingPromote error after content visible: $e',
          );
          // 保持内容可见，不覆盖为错误
        } else {
          _chapterVM.chapterContent.value = AsyncState.error(e);
          _error.value = AppErrorMapper.humanReadable(e);
          _loadPhase.value = ChapterLoadPhase.failed;
        }
      });
      Logging.error('ChapterLoadOrchestrator.run error', exception: e);
    } finally {
      _applyIfCurrent(gen, () {
        _isLoading.value = false;
      });
    }
  }

  Future<void> _runStarting(
    int gen, {
    required bool effectivePreserveContent,
  }) async {
    _setPhase(gen, ChapterLoadPhase.starting);
    if (!effectivePreserveContent) {
      _applyIfCurrent(gen, () {
        _chapterVM.chapterContent.value = AsyncState.loading();
        _isLoading.value = true;
      });
    }
  }

  /// 方案三 T2：staging promote — 安装精确预装箱，零 Rust adopt / 零重装箱。
  Future<void> _runFlutterStagingPromote(
    int gen,
    ChapterLoadRequest request, {
    required bool isForward,
    required Future<void> Function(int chapterIndex, String content)?
    scheduleSearchIndex,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final sw = Stopwatch()..start();
    Logging.info(
      '[Spike] promote ${isForward ? "forward" : "backward"} '
      'chapter=${request.chapterIndex}',
    );
    await _runStarting(gen, effectivePreserveContent: true);
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _pagination.syncChapterTypesetLayoutToRepo();
    final result = await _pagination.paginateFirstScreenFromCache(
      request.chapterIndex,
    );
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    final content = await _contentRepo.loadChapterContent(
      _chapterVM.bookId.value,
      request.chapterIndex,
      readingMode: request.readingMode,
    );
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    final descriptors = _contentRepo.descriptors;
    final pageIndex = isForward
        ? 0
        : ((descriptors?.length ?? 1) - 1).clamp(0, 0x7FFFFFFF);

    _applyIfCurrent(gen, () {
      _chapterVM.chapterContent.value = AsyncState.data(content);
      _chapterVM.chapterIndex.value = request.chapterIndex;
      _totalPages.value = result.totalPages;
      _pageIndex.value = pageIndex;
      _chapterVM.currentCharOffset.value =
          descriptors != null && pageIndex < descriptors.length
          ? descriptors[pageIndex].startOffset
          : 0;
      _chapterVM.pendingJumpCharOffset.value = null;
      _error.value = null;
      _isLoading.value = false;
    });
    if (pageIndex >= 0) {
      _contentRepo.ensurePageWindow(pageIndex);
    }

    _contentRepo.clearAdjacentStaging();
    unawaited(preloadAdjacentFirstPages?.call(request.chapterIndex));

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
    Logging.info(
      '[Spike] promote done pages=${result.totalPages} '
      'page=$pageIndex ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Flutter 分页实验旁路（[kFlutterPaginationSpike]）。
  ///
  /// 只拉章内容 + 走 [SpikePaginationSession]（工厂在 flag 开时创建）；
  /// 不跑 calibration / metrics backfeed / storeLineBreaks。
  ///
  /// 进度：用 [ChapterLoadRequest.initialCharOffset] 落页（字号变更时由
  /// ViewModel 传入当前 charOffset）；翻页写回仍走现有 renderer → navigator。
  Future<void> _runFlutterPaginationSpike(
    int gen,
    ChapterLoadRequest request, {
    required Future<void> Function(int chapterIndex, String content)?
    scheduleSearchIndex,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final preserve = request.preserveContent ?? false;
    Logging.info(
      '[Spike] gen=$gen chapter=${request.chapterIndex} '
      'off=${request.initialCharOffset} preserve=$preserve '
      '(no Rust paginate)',
    );
    await _runStarting(gen, effectivePreserveContent: preserve);
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _pagination.syncChapterTypesetLayoutToRepo();

    final content = await _contentRepo.loadChapterContent(
      _chapterVM.bookId.value,
      request.chapterIndex,
      readingMode: request.readingMode,
    );
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _setPhase(gen, ChapterLoadPhase.fullPaginate);
    // T3：先首屏（maxChars）尽快出页，再 expand 补全；分块 async 装箱不堵死事件循环。
    final quick = await _pagination.paginateFirstScreen(request.chapterIndex);
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _applyIfCurrent(gen, () {
      _chapterVM.chapterContent.value = AsyncState.data(content);
      _chapterVM.chapterIndex.value = request.chapterIndex;
    });

    await _runFinalize(
      gen,
      request,
      content: content,
      total: quick.totalPages,
    );
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    var totalPages = quick.totalPages;
    if (quick.isPartial) {
      Logging.info(
        '[Spike] gen=$gen expand after first-screen pages=${quick.totalPages}',
      );
      totalPages = await _pagination.expandToFullChapter(request.chapterIndex);
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }
      _syncPaginationSignalsAfterRepaginate(
        gen,
        request,
        totalPages: totalPages,
        content: content,
      );
    }

    unawaited(preloadAdjacentFirstPages?.call(request.chapterIndex));

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
    Logging.info(
      '[Spike] gen=$gen done pages=$totalPages '
      'partialWas=${quick.isPartial} '
      'page=${_pageIndex.value} off=${_chapterVM.currentCharOffset.value} '
      'contentLen=${content.length}',
    );
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
      _chapterVM.currentCharOffset.value = request.initialCharOffset.clamp(
        0,
        content.length,
      );
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
        if (request.readingMode == ReadingMode.bilingual &&
            _contentRepo.sessionMode != ChapterPaginationMode.contentBlocks) {
          _chapterVM.readerNotice.value = ReaderNotice.epubRichSkipped;
        }
      }
    });

    // P4-3: scroll 模式预加载相邻章 IR 内容，避免跨章滚动时等待 FFI
    if (request.readingMode == ReadingMode.scroll) {
      final bookId = _chapterVM.bookId.value;
      unawaited(
        _contentRepo
            .loadScrollSegment(
              bookId,
              request.chapterIndex + 1,
              readingMode: ReadingMode.scroll,
            )
            .then((_) {}, onError: (_) {}),
      );
      if (request.chapterIndex > 0) {
        unawaited(
          _contentRepo
              .loadScrollSegment(
                bookId,
                request.chapterIndex - 1,
                readingMode: ReadingMode.scroll,
              )
              .then((_) {}, onError: (_) {}),
        );
      }
    }

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

    Logging.info(
      '[FirstLoad] gen=$gen $logLabel calibration ready'
      ' calib=${calibResult != null}',
    );

    final paginateSw = Stopwatch()..start();
    final quickResult = await paginate();
    if (_isStale(gen)) return null;

    Logging.info(
      '[FirstLoad] gen=$gen $logLabel paginate done'
      ' pages=${quickResult.totalPages} partial=${quickResult.isPartial}'
      ' ${paginateSw.elapsedMilliseconds}ms',
    );

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

    Logging.info(
      '[ChapterTransition] gen=$gen promoteStart direction=${isForward ? "forward" : "backward"}'
      ' chapter_to=${request.chapterIndex} sw=${sw.elapsedMilliseconds}ms',
    );

    // 等待校准完成
    final calibResult = await calibFuture;
    if (_isStale(gen)) return null;
    _pagination.calibration.value ??= calibResult;

    final result = await _pagination.paginateFirstScreenFromCache(
      request.chapterIndex,
    );
    if (_isStale(gen)) return null;

    // beginPaginateFromCache 内部已释放旧 session 并设置新 session/descriptors
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
      _chapterVM.currentCharOffset.value =
          descriptors != null && pageIndex < descriptors.length
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

  /// Phase 6: 分页前预加载全文 → 提取 ICU 行断点 → 存入 Rust 缓存。
  /// 渲染完成后 _storeLineBreaks 会再次触发（覆盖完整索引），
  /// 但预加载确保分页引擎在首次 paginate 时就能拿到索引。
  Future<String> _loadAndMeasureContent(
    int gen,
    ChapterLoadRequest request,
  ) async {
    final text = await _contentRepo.loadChapterContent(
      _chapterVM.bookId.value,
      request.chapterIndex,
      readingMode: request.readingMode,
    );
    // 提取/存储失败不阻塞分页，退化到贪心路径。
    // 即使 plain 为空也尝试 IR 按块断行（图片-only 章等）。
    if (!_isStale(gen)) {
      try {
        await _pagination.storeLineBreaks(text);
      } catch (e) {
        Logging.warning('[LineBreaks] pre-measure store failed: $e');
      }
    }
    return text;
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
              .catchError((Object e) {
                Logging.debug('[Orchestrator] preloadChapter($i) failed: $e');
              }),
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

  /// descriptors 变更后立即同步页码信号，避免 finalize 前 UI 与 Rust 脱节。
  ///
  /// P4 (Bug B) 修复：使用当前 charOffset（而非 request.initialCharOffset）
  /// 重新映射 pageIndex，确保 partial→full 转换时用户停留在同一文本位置，
  /// 即使页边界发生变化页码也可能改变，但内容连续不跳变。
  void _syncPaginationSignalsAfterRepaginate(
    int gen,
    ChapterLoadRequest request, {
    required int totalPages,
    required String content,
  }) {
    if (_isStale(gen)) return;
    if (!_pagination.isPaginationValid(totalPages)) return;

    final oldPage = _pageIndex.value;
    final oldTotal = _totalPages.value;
    final currentCharOffset = _chapterVM.currentCharOffset.value;
    final applied = _pagination.applyFullResult(
      total: totalPages,
      initialCharOffset: currentCharOffset,
      content: content,
    );
    _applyIfCurrent(gen, () {
      _totalPages.value = applied.totalPages;
      _pageIndex.value = applied.pageIndex;
      _chapterVM.currentCharOffset.value = currentCharOffset;
    });

    Logging.info(
      '[LayoutChange] gen=$gen syncAfterRepaginate '
      'totalPages $oldTotal→${applied.totalPages}'
      ' pageIndex $oldPage→${applied.pageIndex}'
      ' off=$currentCharOffset',
    );
  }

  TypesetMeasureParams _typesetMeasureParams() {
    return typesetMeasureParamsFromLayout(
      pageWidth: _pagination.pageWidth,
      pageHeight: _pagination.pageHeight,
      pagePadding: _config.padding.value,
      fontSize: _config.fontSize.value,
      lineHeight: _config.lineHeight.value,
      letterSpacing: _config.letterSpacing.value,
      fontFamily: _pagination.fontFamily,
      devicePixelRatio: _pagination.devicePixelRatio,
      baselineAlign: _config.baselineAlign.value,
      firstLineIndent: _config.firstLineIndent.value,
    );
  }

  /// 首屏渲染后从实际页文本采样 TextPainter metrics（P4-4 / ADR-013）。
  Future<CalibrationData?> _captureMetricsBackfeed(
    int gen,
    int pageIndex,
  ) async {
    try {
      await SchedulerBinding.instance.endOfFrame;
      if (_isStale(gen)) return null;

      final pageText = await _contentRepo.fetchPageContent(pageIndex);
      if (pageText == null || pageText.isEmpty) return null;
      if (_isStale(gen)) return null;

      final baseline = _pagination.calibration.value;
      if (baseline == null) return null;

      final refined = calibrateFromPageText(
        pageText: pageText,
        fontSize: _config.fontSize.value,
        devicePixelRatio: _pagination.devicePixelRatio,
        fontFamily: _pagination.fontFamily,
        lineHeight: _config.lineHeight.value,
        letterSpacing: _config.letterSpacing.value,
        width: _pagination.pageWidth,
        height: _pagination.pageHeight,
        padding: _config.padding.value,
        baseline: baseline,
      );
      if (refined == null || !calibrationDriftExceeds(baseline, refined)) {
        return null;
      }
      if (!isCalibrationPlausible(refined, _config.fontSize.value)) {
        Logging.info(
          '[MetricsBackfeed] refined calibration failed plausibility check, '
          'discarding',
        );
        return null;
      }

      Logging.info(
        '[MetricsBackfeed] page=$pageIndex cjk '
        '${baseline.cjkWidth.toStringAsFixed(2)}→'
        '${refined.cjkWidth.toStringAsFixed(2)}',
      );
      return refined;
    } catch (e) {
      Logging.warning('[MetricsBackfeed] capture failed: $e');
      return null;
    }
  }
}
