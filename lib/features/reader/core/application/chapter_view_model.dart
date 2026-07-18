import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine.dart';
import 'package:zephyr_reader/core/reader_engine/shared/auto_scroll_controller.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_boundary_coordinator.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_chapter_segment.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_layout_params.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_orchestrator.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/application/search_index_lifecycle.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'package:zephyr_reader/src/rust/domain/chapter/models.dart';

/// 章节视图模型
///
/// 持有 chapter-level signals 并协调加载、导航、分页、滚动、自动滚动和搜索索引。
/// PaginationCoordinator、ScrollBoundaryCoordinator、AutoScrollController、
/// SearchIndexLifecycle 仍然保持独立职责，避免单一类过于膨胀。
@injectable
class ChapterViewModel {
  // ==================== 核心信号 ====================
  final bookId = signal<String>('0');
  final chapterIndex = signal<int>(0);
  final currentCharOffset = signal<int>(0);
  final chapterContent = asyncSignal<String>(AsyncState.data(''));
  final pendingJumpCharOffset = signal<int?>(null);

  /// 当前章节切换是否显示 AnimatedSwitcher 过渡动画。
  /// `manualJump` 时 true（默认），`adjacentCrossChapter` 时 false。
  final showChapterTransition = signal<bool>(true);

  /// 滚动模式多章拼接段（plain text 跨章滚动）。
  final scrollSegments = signal<List<ScrollChapterSegment>>([]);

  /// 当前生效的阅读模式（由 ReaderViewModel 同步，供导航器加载章节时使用）。
  ReadingMode activeReadingMode = ReadingMode.pagination;

  // ==================== 加载轴信号 ====================
  final chapters = asyncSignal<List<Chapter>>(AsyncState.data([]));
  final totalPages = signal<int>(0);
  final pageIndex = signal<int>(0);
  final isLoading = signal<bool>(false);
  final error = signal<String?>(null);
  final loadPhase = signal<ChapterLoadPhase>(ChapterLoadPhase.idle);

  // ==================== 依赖 ====================
  final ChapterContentRepository _contentRepo;
  final PaginationEngine _engine;
  final ProgressRepository _progressRepo;
  final ReaderConfig _config;

  late final ScrollBoundaryCoordinator _scrollBoundary;
  late final PaginationCoordinator _pagination;
  late final ChapterLoadOrchestrator _orchestrator;
  late final SearchIndexLifecycle _searchIndex;
  late final AutoScrollController _autoScroll;

  // ==================== 跨章导航常量 ====================
  /// 后退到上一章时，用超大 offset 让 finalize 解析到末页。
  static const int _preferLastPageCharOffset = 0x7FFFFFFF;

  ChapterViewModel(
    this._contentRepo,
    this._engine,
    this._progressRepo,
    this._config,
  ) {
    _scrollBoundary = ScrollBoundaryCoordinator(
      contentRepo: _contentRepo,
      onPositionChanged: (chapterIdx, offset) {
        chapterIndex.value = chapterIdx;
        currentCharOffset.value = offset;
      },
      onChapterChanged: (chapterIdx) {
        chapterIndex.value = chapterIdx;
      },
      onSegmentsChanged: (segments) {
        scrollSegments.value = segments;
      },
    );
    _pagination = PaginationCoordinator(_contentRepo, _engine, _config, this);
    _orchestrator = ChapterLoadOrchestrator(
      contentRepo: _contentRepo,
      engine: _engine,
      chapterVM: this,
      pagination: _pagination,
      chapters: chapters,
      totalPages: totalPages,
      pageIndex: pageIndex,
      isLoading: isLoading,
      error: error,
      loadPhase: loadPhase,
    );
    _searchIndex = SearchIndexLifecycle(this, chapters);
    _orchestratorScheduleSearchIndex = _searchIndex.scheduleIndex;
    _orchestratorPreloadAdjacentFirstPages = preloadAdjacentFirstPages;
    _autoScroll = AutoScrollController(_config);
  }

  // ==================== 布局参数（委托 PaginationCoordinator）====================

  double get pageWidth => _pagination.pageWidth;
  set pageWidth(double value) {
    _pagination.pageWidth = value;
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  double get pageHeight => _pagination.pageHeight;
  set pageHeight(double value) {
    _pagination.pageHeight = value;
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  double get devicePixelRatio => _pagination.devicePixelRatio;
  set devicePixelRatio(double value) {
    _pagination.devicePixelRatio = value;
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  TextScaler get textScaler => _pagination.textScaler;
  set textScaler(TextScaler value) {
    _pagination.textScaler = value;
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  late final ReadonlySignal<String> progressText = computed(() {
    final totalChapters = chapters.value.value?.length ?? 0;
    if (totalChapters == 0) return '0%';
    final chapterProgress = (chapterIndex.value + 1) / totalChapters;
    return '${(chapterProgress * 100).toStringAsFixed(1)}%';
  });

  late final ReadonlySignal<String> currentChapterTitle = computed(() {
    final chapterList = chapters.value.value ?? [];
    if (chapterIndex.value >= 0 && chapterIndex.value < chapterList.length) {
      return chapterList[chapterIndex.value].title;
    }
    return '';
  });

  // ==================== orchestrator 回调注入 ====================
  late final Future<void> Function(int chapterIndex, String content)?
  _orchestratorScheduleSearchIndex;
  late final Future<void> Function(int chapterIndex)?
  _orchestratorPreloadAdjacentFirstPages;

  // ==================== 字体与校准 ====================

  String get fontFamily => _pagination.fontFamily;
  set fontFamily(String value) {
    _pagination.fontFamily = value;
  }

  void updateFont(String fontFamily) {
    _pagination.fontFamily = fontFamily;
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  // ==================== 章节加载 ====================

  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final data = await _contentRepo.getChapters(bookId.value);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      Logging.error(
        'Failed to load chapter list (book=${bookId.value})',
        exception: e,
      );
      chapters.value = AsyncState.error(e);
      rethrow;
    }
  }

  Future<void> loadLastProgress() async {
    try {
      final progress = await _progressRepo.load(bookId.value);
      if (progress != null) {
        chapterIndex.value = progress.chapterIndex;
        currentCharOffset.value = progress.charOffset;
      }
    } catch (e) {
      Logging.error('Failed to load reading progress', exception: e);
    }
  }

  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    ReadingMode readingMode = ReadingMode.pagination,
    Future<void> Function()? onChapterLoaded,
    bool? preserveContent,
    ChapterNavigationKind navigationKind = ChapterNavigationKind.manualJump,
  }) {
    showChapterTransition.value =
        (navigationKind == ChapterNavigationKind.manualJump);
    _pagination.syncChapterTypesetLayoutToRepo();
    return _orchestrator.run(
      ChapterLoadRequest(
        chapterIndex: chapterIndex,
        initialCharOffset: initialCharOffset,
        readingMode: readingMode,
        preserveContent: preserveContent,
        onChapterLoaded: onChapterLoaded,
        navigationKind: navigationKind,
      ),
      scheduleSearchIndex: _orchestratorScheduleSearchIndex,
      preloadAdjacentFirstPages: _orchestratorPreloadAdjacentFirstPages,
    );
  }

  // ==================== 跨章导航 ====================

  Future<void> previousChapter() async {
    if (isLoading.value) return;
    final fromChapter = chapterIndex.value;
    if (fromChapter > 0) {
      final newChapterIndex = fromChapter - 1;
      showChapterTransition.value = false;
      final sw = Stopwatch()..start();
      await loadChapter(
        newChapterIndex,
        preserveContent: true,
        readingMode: activeReadingMode,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        initialCharOffset: _preferLastPageCharOffset,
      );
      Logging.info(
        '[ChapterTransition] backward: from=$fromChapter to=$newChapterIndex total_ms=${sw.elapsedMilliseconds}',
      );
    }
  }

  Future<void> nextChapter() async {
    if (isLoading.value) return;
    final chapterList = chapters.value.value ?? [];
    final fromChapter = chapterIndex.value;
    if (fromChapter < chapterList.length - 1) {
      final newChapterIndex = fromChapter + 1;
      showChapterTransition.value = false;
      final sw = Stopwatch()..start();
      await loadChapter(
        newChapterIndex,
        preserveContent: true,
        readingMode: activeReadingMode,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
      );
      Logging.info(
        '[ChapterTransition] forward: from=$fromChapter to=$newChapterIndex total_ms=${sw.elapsedMilliseconds}',
      );
    }
  }

  Future<void> jumpToChapter(int chapterIndex) async {
    showChapterTransition.value = true;
    await loadChapter(chapterIndex, readingMode: activeReadingMode);
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    showChapterTransition.value = true;
    await loadChapter(
      chapterIndex,
      initialCharOffset: charOffset,
      readingMode: activeReadingMode,
    );
  }

  // ==================== 页面导航 ====================

  Future<void> previousPage() async {
    if (pageIndex.value > 0) {
      loadPage(pageIndex.value - 1);
    } else {
      await previousChapter();
    }
  }

  Future<void> nextPage() async {
    if (pageIndex.value < totalPages.value - 1) {
      loadPage(pageIndex.value + 1);
    } else {
      await nextChapter();
    }
  }

  void loadPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= totalPages.value) return;
    this.pageIndex.value = pageIndex;

    final pagePlans = _engine.session.pagePlans;
    if (pagePlans != null && pageIndex < pagePlans.length) {
      final p = pagePlans[pageIndex];
      final start = p.startUtf16;
      final end = p.endUtf16;
      // 书签/跳转用页内偏移，避免落在页边界导致解析到上一页。
      final inside = end > start + 1 ? start + 1 : start;
      currentCharOffset.value = inside;
    }

    _engine.session.ensureWindow(pageIndex);
    // pageIndex <= 1 时加速上一章 staging 预加载
    _ensurePrevChapterStaging(pageIndex);
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = chapterContent.value.value?.length ?? 0;
    currentCharOffset.value = charOffset.clamp(0, contentLength);
  }

  void consumePendingJumpOffset() {
    pendingJumpCharOffset.value = null;
  }

  // ==================== 相邻章 staging 预加载 ====================

  /// 预加载相邻章节 staging（prev 末页 + next 首页）。
  Future<void> preloadAdjacentFirstPages(int centerIndex) async {
    final chapterList = chapters.value.value ?? [];
    if (chapterList.isEmpty) return;
    final effectiveHeight = _pagination.pageHeight;

    // 预加载下一章
    if (centerIndex + 1 < chapterList.length) {
      final nextIdx = centerIndex + 1;
      unawaited(
        _contentRepo.preloadNextChapterStaging(
          bookId.value,
          nextIdx,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: _pagination.pageWidth,
          height: effectiveHeight,
          padding: _config.padding.value,
          devicePixelRatio: _pagination.devicePixelRatio,
          fontFamily: _pagination.fontFamily,
        ),
      );
    }

    // 预加载上一章（末页）
    if (centerIndex - 1 >= 0) {
      final prevIdx = centerIndex - 1;
      unawaited(
        _contentRepo.preloadPreviousChapterStaging(
          bookId.value,
          prevIdx,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: _pagination.pageWidth,
          height: effectiveHeight,
          padding: _config.padding.value,
          devicePixelRatio: _pagination.devicePixelRatio,
          fontFamily: _pagination.fontFamily,
        ),
      );
    }
  }

  /// 条件触发上一章 staging 预加载（pageIndex <= 2 时提前触发）。
  void _ensurePrevChapterStaging(int pageIndex) {
    if (pageIndex > 2) return;
    final centerIndex = chapterIndex.value;
    if (centerIndex - 1 < 0) return;
    if (_contentRepo.prevChapterStaging != null) return;
    unawaited(
      _contentRepo.preloadPreviousChapterStaging(
        bookId.value,
        centerIndex - 1,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: _pagination.pageWidth,
        height: _pagination.pageHeight,
        padding: _config.padding.value,
        devicePixelRatio: _pagination.devicePixelRatio,
        fontFamily: _pagination.fontFamily,
      ),
    );
  }

  // ==================== 自动滚动（委托 AutoScrollController）====================

  Signal<int> get autoScrollTick => _autoScroll.autoScrollTick;

  void startAutoScroll() => _autoScroll.startAutoScroll();
  void stopAutoScroll() => _autoScroll.stopAutoScroll();

  // ==================== 滚动模式 ====================

  void resetScrollDocument(
    String content,
    int chapterIndex, {
    ReaderChapterIr? chapterIr,
    String? chapterFilePath,
  }) {
    _scrollBoundary.reset(
      bookId.value,
      chapterIndex,
      content,
      chapterIr: chapterIr,
      chapterFilePath: chapterFilePath,
    );
  }

  Future<void> scrollAppendNext(ReadingMode readingMode) {
    _pagination.syncChapterTypesetLayoutToRepo();
    return _scrollBoundary.appendNext(
      bookId: bookId.value,
      readingMode: readingMode,
    );
  }

  Future<int> scrollPrependPrev(ReadingMode readingMode) async {
    _pagination.syncChapterTypesetLayoutToRepo();
    final before = _scrollBoundary.segments.fold<int>(
      0,
      (sum, s) => sum + s.paragraphCount,
    );
    await _scrollBoundary.prependPrev(
      bookId: bookId.value,
      readingMode: readingMode,
    );
    final after = _scrollBoundary.segments.fold<int>(
      0,
      (sum, s) => sum + s.paragraphCount,
    );
    return after - before;
  }

  bool get hasScrollSegments => scrollSegments.value.isNotEmpty;

  void reportScrollPosition(double scrollOffset, ScrollLayoutParams layout) {
    _scrollBoundary.reportScrollPosition(scrollOffset, layout);
  }

  // ==================== 重置 ====================

  void reset() {
    _pagination.disposePagination();
    _autoScroll.reset();
    _searchIndex.cancel();
    _orchestrator.resetPhase();
    bookId.value = '0';
    chapterIndex.value = 0;
    chapters.value = AsyncState.data([]);
    totalPages.value = 0;
    pageIndex.value = 0;
    isLoading.value = false;
    error.value = null;
    chapterContent.value = AsyncState.data('');
    currentCharOffset.value = 0;
    pendingJumpCharOffset.value = null;
    scrollSegments.value = [];
  }
}
