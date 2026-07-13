// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';
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
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_progress_hook.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节加载显式状态机：分阶段执行 [ChapterLoadRequest] 并防止竞态写信号。
class ChapterLoadOrchestrator {
  static const int _preloadCount = 3;

  ChapterLoadOrchestrator({
    required ReaderRepositoryInterface contentRepo,
    required ChapterViewModel chapterVM,
    required PaginationCoordinator pagination,
    required AsyncSignal<List<Chapter>> chapters,
    required Signal<int> totalPages,
    required Signal<int> pageIndex,
    required Signal<bool> isLoading,
    required Signal<String?> error,
    required Signal<ChapterLoadPhase> loadPhase,
  }) : _contentRepo = contentRepo,
       _chapterVM = chapterVM,
       _pagination = pagination,
       _chapters = chapters,
       _totalPages = totalPages,
       _pageIndex = pageIndex,
       _isLoading = isLoading,
       _error = error,
       _loadPhase = loadPhase;

  final ReaderRepositoryInterface _contentRepo;
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

      // ADR-016：Flutter 精确分页为唯一产品路径。
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
      await _runFlutterPagination(
        gen,
        request,
        scheduleSearchIndex: scheduleSearchIndex,
        preloadAdjacentFirstPages: preloadAdjacentFirstPages,
      );
      return;
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
      '[FlutterPagination] promote ${isForward ? "forward" : "backward"} '
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
      '[FlutterPagination] promote done pages=${result.totalPages} '
      'page=$pageIndex ${sw.elapsedMilliseconds}ms',
    );
  }

  /// Flutter 精确分页（ADR-016 产品路径）。
  ///
  /// 只拉章内容 + 走 [FlutterPaginationSession]；
  /// 不跑 calibration / metrics backfeed / storeLineBreaks。
  ///
  /// 进度：用 [ChapterLoadRequest.initialCharOffset] 落页（字号变更时由
  /// ViewModel 传入当前 charOffset）；翻页写回仍走现有 renderer → navigator。
  Future<void> _runFlutterPagination(
    int gen,
    ChapterLoadRequest request, {
    required Future<void> Function(int chapterIndex, String content)?
    scheduleSearchIndex,
    Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages,
  }) async {
    final preserve = request.preserveContent ?? false;
    Logging.info(
      '[FlutterPagination] gen=$gen chapter=${request.chapterIndex} '
      'off=${request.initialCharOffset} preserve=$preserve '
      '(no Rust paginate)',
    );
    await _runStarting(gen, effectivePreserveContent: preserve);
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _pagination.syncChapterTypesetLayoutToRepo();

    _setPhase(gen, ChapterLoadPhase.fullPaginate);
    // 正文加载与首屏装箱并行（避免串行等两遍大 TXT）。
    final contentFuture = _contentRepo.loadChapterContent(
      _chapterVM.bookId.value,
      request.chapterIndex,
      readingMode: request.readingMode,
    );
    final quickFuture = _pagination.paginateFirstScreen(request.chapterIndex);
    final content = await contentFuture;
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }
    final quick = await quickFuture;
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    _applyIfCurrent(gen, () {
      _chapterVM.chapterContent.value = AsyncState.data(content);
      _chapterVM.chapterIndex.value = request.chapterIndex;
    });

    await _runFinalize(gen, request, content: content, total: quick.totalPages);
    if (_isStale(gen)) {
      _setPhase(gen, ChapterLoadPhase.cancelled);
      return;
    }

    // 首屏已可翻：先关 loading（对齐主线 firstSpine），expand 在后台补全。
    _applyIfCurrent(gen, () {
      _isLoading.value = false;
    });

    // 等 LayoutBuilder 真正上报 bodyHeight（信号更新后往往要再等 1–2 帧）。
    for (var i = 0; i < 5; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (_isStale(gen)) {
        _setPhase(gen, ChapterLoadPhase.cancelled);
        return;
      }
      if (PaginationViewportMetrics.contentHeightDp != null) break;
    }
    Logging.info(
      '[FlutterPagination] gen=$gen viewport ready '
      'H=${PaginationViewportMetrics.contentHeightDp?.toStringAsFixed(0) ?? "null"} '
      'W=${PaginationViewportMetrics.contentWidthDp?.toStringAsFixed(0) ?? "null"}',
    );

    var totalPages = quick.totalPages;
    // 有实测视口则整章重装；否则仅 expand 补全。
    Logging.info(
      '[FlutterPagination] gen=$gen rebox after first-screen pages=${quick.totalPages}',
    );
    paginationProgressHook = (pages, partial) {
      _applyIfCurrent(gen, () {
        if (pages > _totalPages.value) {
          _totalPages.value = pages;
        }
      });
    };
    try {
      final full = await _pagination.paginateFullChapter(request.chapterIndex);
      totalPages = full.totalPages;
    } finally {
      paginationProgressHook = null;
    }
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
      '[FlutterPagination] gen=$gen done pages=$totalPages '
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

    // scroll 模式预加载相邻章 IR 内容，避免跨章滚动时等待 FFI
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

  /// normalLoad / configReload 共用：校准 → partial paginate → 按 offset 落页。

  /// expandOnly：同章同 config，handle 已存在则直接 expand to full。
  /// session 不存在时退回 normalLoad 等价路径。

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
}
