import 'package:signals_flutter/signals_flutter.dart';

import 'package:injectable/injectable.dart';

import 'package:zephyr_reader/features/reader/core/application/auto_scroll_controller.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_navigator.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/application/search_index_lifecycle.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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

  late final PaginationCoordinator _pagination;
  late final ChapterLoader _loader;
  late final SearchIndexLifecycle _searchIndex;
  late final ChapterNavigator _navigator;
  late final AutoScrollController _autoScroll;

  ChapterViewModel(
    @factoryParam ReaderRepositoryInterface repo,
    @factoryParam ReaderConfig config,
  ) {
    _pagination = PaginationCoordinator(repo, config, this);
    _loader = ChapterLoader(repo, config, this, _pagination);
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
  set pageWidth(double value) => _pagination.pageWidth = value;

  double get pageHeight => _pagination.pageHeight;
  set pageHeight(double value) => _pagination.pageHeight = value;

  double get devicePixelRatio => _pagination.devicePixelRatio;
  set devicePixelRatio(double value) => _pagination.devicePixelRatio = value;
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

  void updateFont(String fontFamily) => _loader.updateFont(fontFamily);

  // ==================== 章节加载（委托 ChapterLoader）====================

  Future<void> loadChapters() => _loader.loadChapters();
  Future<void> loadLastProgress() => _loader.loadLastProgress();
  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    ChapterPaginationIntent intent = ChapterPaginationIntent.normalLoad,
    ReadingMode readingMode = ReadingMode.pagination,
    Future<void> Function()? onChapterLoaded,
    bool preserveContent = false,
  }) => _loader.loadChapter(
    chapterIndex,
    initialCharOffset: initialCharOffset,
    intent: intent,
    readingMode: readingMode,
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
  }
}
