import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/core/application/auto_scroll_controller.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_navigator.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/application/search_index_lifecycle.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';

/// 章节视图模型
///
/// Facade：委托给 ChapterLoader、PaginationCoordinator、ChapterNavigator、
/// AutoScrollController 和 SearchIndexLifecycle。
/// 不持有 UI 面板状态（由 ReaderViewModel Facade 协调）。
class ChapterViewModel {
  final ReaderPageState _pageState;

  late final PaginationCoordinator _pagination;
  late final ChapterLoader _loader;
  late final SearchIndexLifecycle _searchIndex;
  late final ChapterNavigator _navigator;
  late final AutoScrollController _autoScroll;

  ChapterViewModel(
    ReaderRepositoryInterface repo,
    ReaderConfig config,
    ReaderPageState pageState,
  ) : _pageState = pageState {
    _pageState.bookId.value = '0';
    _pagination = PaginationCoordinator(repo, config, pageState);
    _loader = ChapterLoader(repo, config, pageState, _pagination);
    _searchIndex = SearchIndexLifecycle(pageState, _loader.chapters);
    _loader.scheduleSearchIndex = _searchIndex.scheduleIndex;
    _navigator = ChapterNavigator(
      repo,
      config,
      pageState,
      _loader,
      _pagination,
      _loader.chapters,
      _loader.totalPages,
      _loader.pageIndex,
    );
    _loader.preloadAdjacentFirstPages = _navigator.preloadAdjacentFirstPages;
    _autoScroll = AutoScrollController(config);
  }

  /// 测试用 — 暴露共享状态供测试断言。
  ReaderPageState get pageState => _pageState;

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
  set pageWidth(double value) => _pagination.pageWidth = value;

  double get pageHeight => _pagination.pageHeight;
  set pageHeight(double value) => _pagination.pageHeight = value;

  double get devicePixelRatio => _pagination.devicePixelRatio;
  set devicePixelRatio(double value) => _pagination.devicePixelRatio = value;

  // ==================== 计算信号 ====================

  late final ReadonlySignal<String> progressText = computed(() {
    final totalChapters = chapters.value.value?.length ?? 0;
    if (totalChapters == 0) return '0%';
    final chapterProgress =
        (_pageState.chapterIndex.value + 1) / totalChapters;
    return '${(chapterProgress * 100).toStringAsFixed(1)}%';
  });

  late final ReadonlySignal<String> currentChapterTitle = computed(() {
    final chapterList = chapters.value.value ?? [];
    if (_pageState.chapterIndex.value >= 0 &&
        _pageState.chapterIndex.value < chapterList.length) {
      return chapterList[_pageState.chapterIndex.value].title;
    }
    return '';
  });

  // ==================== 字体与校准 ====================

  void updateFont(String fontFamily) => _loader.updateFont(fontFamily);

  // ==================== 章节加载（委托 ChapterLoader）====================

  Future<void> loadChapters() => _loader.loadChapters();
  Future<void> loadLastProgress() => _loader.loadLastProgress();

  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    bool restartSession = true,
    Future<void> Function()? onChapterLoaded,
    bool preserveContent = false,
  }) =>
      _loader.loadChapter(
        chapterIndex,
        initialCharOffset: initialCharOffset,
        restartSession: restartSession,
        onChapterLoaded: onChapterLoaded,
        preserveContent: preserveContent,
      );

  // ==================== 章节导航（委托 ChapterNavigator）====================

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

  // ==================== 自动滚动（委托 AutoScrollController）====================

  void startAutoScroll() => _autoScroll.startAutoScroll();
  void stopAutoScroll() => _autoScroll.stopAutoScroll();

  // ==================== 重置 ====================

  void reset() {
    _pagination.disposePagination();
    _autoScroll.reset();
    _searchIndex.cancel();
    _pageState.bookId.value = '0';
    _pageState.chapterIndex.value = 0;
    _loader.resetSignals();
    _pageState.chapterContent.value = AsyncState.data('');
    _pageState.currentCharOffset.value = 0;
    _pageState.pendingJumpCharOffset.value = null;
  }
}
