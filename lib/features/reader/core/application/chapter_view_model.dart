import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/features/reader/core/application/auto_scroll_controller.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_navigator.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/application/scroll_boundary_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/application/search_index_lifecycle.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_notice.dart';

import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

/// 章节视图模型
///
/// Facade：委托给 ChapterLoader、PaginationCoordinator、ChapterNavigator、
/// AutoScrollController 和 SearchIndexLifecycle。
/// 持有 5 个 chapter-level signals（bookId/chapterIndex/currentCharOffset/
/// chapterContent/pendingJumpCharOffset），原 ReaderPageState 字段，Phase 3.2 PR1 迁入。
@injectable
class ChapterViewModel {
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

  /// 当前生效的阅读模式（由 [ReaderViewModel] 同步，供导航器加载章节时使用）。
  ReadingMode activeReadingMode = ReadingMode.pagination;

  /// 待 UI 层展示的用户通知（如 EPUB 富文本降级）。
  final readerNotice = signal<ReaderNotice?>(null);

  late final ScrollBoundaryCoordinator _scrollBoundary;
  late final PaginationCoordinator _pagination;
  late final ChapterLoader _loader;
  late final SearchIndexLifecycle _searchIndex;
  late final ChapterNavigator _navigator;
  late final AutoScrollController _autoScroll;

  ChapterViewModel(
    @factoryParam ReaderRepositoryInterface repo,
    @factoryParam ReaderConfig config,
  ) {
    _scrollBoundary = ScrollBoundaryCoordinator(
      repo: repo,
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
      onReaderNotice: (notice) {
        readerNotice.value = notice;
      },
    );
    _pagination = PaginationCoordinator(repo, config, this);
    _loader = ChapterLoader(repo, this, _pagination);
    _searchIndex = SearchIndexLifecycle(this, _loader.chapters);
    _loader.scheduleSearchIndex = _searchIndex.scheduleIndex;
    _navigator = ChapterNavigator(
      repo,
      config,
      this,
      _loader,
      _pagination,
      _loader.chapters,
      _loader.totalPages,
      _loader.pageIndex,
    );
    _loader.preloadAdjacentFirstPages = _navigator.preloadAdjacentFirstPages;
    _autoScroll = AutoScrollController(config);
  }

  // ==================== 委托信号 ====================
  AsyncSignal<List<Chapter>> get chapters => _loader.chapters;
  Signal<int> get totalPages => _loader.totalPages;
  Signal<int> get pageIndex => _loader.pageIndex;
  Signal<bool> get isLoading => _loader.isLoading;
  Signal<String?> get error => _loader.error;
  Signal<ChapterLoadPhase> get loadPhase => _loader.loadPhase;
  Signal<int> get autoScrollTick => _autoScroll.autoScrollTick;

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

  // ==================== 字体与校准 ====================

  String get fontFamily => _pagination.fontFamily;
  set fontFamily(String value) {
    _pagination.fontFamily = value;
  }

  void updateFont(String fontFamily) {
    _loader.updateFont(fontFamily);
    _pagination.syncChapterTypesetLayoutToRepo();
  }

  // ==================== 章节加载（委托 ChapterLoader）====================

  Future<void> loadChapters() => _loader.loadChapters();
  Future<void> loadLastProgress() => _loader.loadLastProgress();
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
    return _loader.loadChapter(
      chapterIndex,
      initialCharOffset: initialCharOffset,
      readingMode: readingMode,
      onChapterLoaded: onChapterLoaded,
      preserveContent: preserveContent,
      navigationKind: navigationKind,
    );
  }

  Future<void> previousChapter() => _navigator.previousChapter();
  Future<void> nextChapter() => _navigator.nextChapter();
  Future<void> jumpToChapter(int chapterIndex) =>
      _navigator.jumpToChapter(chapterIndex);
  Future<void> jumpToPosition(int chapterIndex, int charOffset) =>
      _navigator.jumpToPosition(chapterIndex, charOffset);

  // ==================== 页面导航（委托 ChapterNavigator）====================

  Future<void> previousPage() => _navigator.previousPage();
  Future<void> nextPage() => _navigator.nextPage();
  void loadPage(int pageIndex) => _navigator.loadPage(pageIndex);
  void updateCurrentCharOffset(int charOffset) =>
      _navigator.updateCurrentCharOffset(charOffset);
  void consumePendingJumpOffset() => _navigator.consumePendingJumpOffset();

  /// 滚动模式：重置到单章（手动跳章 / 换书 / 配置重载）。
  void resetScrollDocument(
    String content,
    int chapterIndex, {
    List<RichParagraph>? richParagraphs,
    TextSpan? richRootSpan,
    ChapterContentIr? chapterIr,
    String? chapterFilePath,
  }) {
    _scrollBoundary.reset(
      bookId.value,
      chapterIndex,
      content,
      richParagraphs: richParagraphs,
      richRootSpan: richRootSpan,
      chapterIr: chapterIr,
      chapterFilePath: chapterFilePath,
    );
  }

  /// 滚动模式：滚近底时追加下一章。
  Future<void> scrollAppendNext(ReadingMode readingMode) {
    _pagination.syncChapterTypesetLayoutToRepo();
    return _scrollBoundary.appendNext(
      bookId: bookId.value,
      readingMode: readingMode,
    );
  }

  /// 滚动模式：滚近顶时前置上一章。返回新增段落数（用于补偿 scroll offset）。
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

  /// 滚动模式是否已启用多章拼接（plain text）。
  bool get hasScrollSegments => scrollSegments.value.isNotEmpty;

  /// 滚动模式：根据 scrollOffset 更新 (chapterIndex, charOffset)。
  void reportScrollPosition(double scrollOffset, ScrollLayoutParams layout) {
    _scrollBoundary.reportScrollPosition(scrollOffset, layout);
  }

  // ==================== 自动滚动（委托 AutoScrollController）====================

  void startAutoScroll() => _autoScroll.startAutoScroll();
  void stopAutoScroll() => _autoScroll.stopAutoScroll();
  void reset() {
    _pagination.disposePagination();
    _autoScroll.reset();
    _searchIndex.cancel();
    bookId.value = '0';
    chapterIndex.value = 0;
    _loader.resetSignals();
    chapterContent.value = AsyncState.data('');
    currentCharOffset.value = 0;
    pendingJumpCharOffset.value = null;
    scrollSegments.value = [];
  }
}
