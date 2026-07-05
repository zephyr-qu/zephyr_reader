import 'dart:async';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节与页面导航。
class ChapterNavigator {
  final ReaderRepositoryInterface _repo;
  final ReaderConfig _config;
  final ChapterViewModel _chapterVM;
  final ChapterLoader _loader;
  final PaginationCoordinator _pagination;
  final AsyncSignal<List<Chapter>> _chapters;
  final Signal<int> _totalPages;
  final Signal<int> _pageIndex;

  ChapterNavigator(
    this._repo,
    this._config,
    this._chapterVM,
    this._loader,
    this._pagination,
    this._chapters,
    this._totalPages,
    this._pageIndex,
  );

  /// 后退到上一章时，用超大 offset 让 finalize 解析到末页。
  static const int preferLastPageCharOffset = 0x7FFFFFFF;

  Future<void> previousChapter() async {
    if (_loader.isLoading.value) return;
    final fromChapter = _chapterVM.chapterIndex.value;
    if (fromChapter > 0) {
      final newChapterIndex = fromChapter - 1;
      _chapterVM.showChapterTransition.value = false;
      final sw = Stopwatch()..start();
      await _loader.loadChapter(
        newChapterIndex,
        preserveContent: true,
        readingMode: _chapterVM.activeReadingMode,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        initialCharOffset: preferLastPageCharOffset,
      );
      Logging.info(
        '[ChapterTransition] backward: from=$fromChapter to=$newChapterIndex total_ms=${sw.elapsedMilliseconds}',
      );
    }
  }

  Future<void> nextChapter() async {
    if (_loader.isLoading.value) return;
    final chapterList = _chapters.value.value ?? [];
    final fromChapter = _chapterVM.chapterIndex.value;
    if (fromChapter < chapterList.length - 1) {
      final newChapterIndex = fromChapter + 1;
      _chapterVM.showChapterTransition.value = false;
      final sw = Stopwatch()..start();
      await _loader.loadChapter(
        newChapterIndex,
        preserveContent: true,
        readingMode: _chapterVM.activeReadingMode,
        navigationKind: ChapterNavigationKind.adjacentCrossChapter,
      );
      Logging.info(
        '[ChapterTransition] forward: from=$fromChapter to=$newChapterIndex total_ms=${sw.elapsedMilliseconds}',
      );
    }
  }

  Future<void> jumpToChapter(int chapterIndex) async {
    _chapterVM.showChapterTransition.value = true;
    await _loader.loadChapter(
      chapterIndex,
      readingMode: _chapterVM.activeReadingMode,
    );
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    _chapterVM.showChapterTransition.value = true;
    await _loader.loadChapter(
      chapterIndex,
      initialCharOffset: charOffset,
      readingMode: _chapterVM.activeReadingMode,
    );
  }

  Future<void> previousPage() async {
    if (_pageIndex.value > 0) {
      loadPage(_pageIndex.value - 1);
    } else {
      await previousChapter();
    }
  }

  Future<void> nextPage() async {
    if (_pageIndex.value < _totalPages.value - 1) {
      loadPage(_pageIndex.value + 1);
    } else {
      await nextChapter();
    }
  }

  void loadPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _totalPages.value) return;
    _pageIndex.value = pageIndex;

    final descriptors = _repo.descriptors;
    if (descriptors != null && pageIndex < descriptors.length) {
      final d = descriptors[pageIndex];
      final start = d.startOffset;
      final end = d.endOffset;
      // 书签/跳转用页内偏移，避免落在页边界导致解析到上一页。
      final inside = end > start + 1 ? start + 1 : start;
      _chapterVM.currentCharOffset.value = inside;
    }

    _repo.ensurePageWindow(pageIndex);
    // pageIndex <= 1 时加速上一章 staging 预加载
    ensurePrevChapterStaging(pageIndex);
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = _chapterVM.chapterContent.value.value?.length ?? 0;
    _chapterVM.currentCharOffset.value = charOffset.clamp(0, contentLength);
  }

  void consumePendingJumpOffset() {
    _chapterVM.pendingJumpCharOffset.value = null;
  }

  /// 预加载相邻章节 staging（prev 末页 + next 首页）。
  Future<void> preloadAdjacentFirstPages(int centerIndex) async {
    final chapterList = _chapters.value.value ?? [];
    if (chapterList.isEmpty) return;
    final effectiveHeight =
        _pagination.pageHeight -
        2 * ReaderRenderConfig.pageContentVerticalPadding;

    // 预加载下一章
    if (centerIndex + 1 < chapterList.length) {
      final nextIdx = centerIndex + 1;
      unawaited(
        _repo.preloadNextChapterStaging(
          _chapterVM.bookId.value,
          nextIdx,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: _pagination.pageWidth,
          height: effectiveHeight.clamp(100, _pagination.pageHeight),
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
        _repo.preloadPreviousChapterStaging(
          _chapterVM.bookId.value,
          prevIdx,
          fontSize: _config.fontSize.value,
          lineHeight: _config.lineHeight.value,
          width: _pagination.pageWidth,
          height: effectiveHeight.clamp(100, _pagination.pageHeight),
          padding: _config.padding.value,
          devicePixelRatio: _pagination.devicePixelRatio,
          fontFamily: _pagination.fontFamily,
        ),
      );
    }
  }

  /// 条件触发上一章 staging 预加载（pageIndex <= 2 时提前触发）。
  void ensurePrevChapterStaging(int pageIndex) {
    if (pageIndex > 2) return;
    final centerIndex = _chapterVM.chapterIndex.value;
    if (centerIndex - 1 < 0) return;
    if (_repo.prevChapterStaging != null) return;
    unawaited(
      _repo.preloadPreviousChapterStaging(
        _chapterVM.bookId.value,
        centerIndex - 1,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: _pagination.pageWidth,
        height:
            (_pagination.pageHeight -
                    2 * ReaderRenderConfig.pageContentVerticalPadding)
                .clamp(100, _pagination.pageHeight),
        padding: _config.padding.value,
        devicePixelRatio: _pagination.devicePixelRatio,
        fontFamily: _pagination.fontFamily,
      ),
    );
  }
}
