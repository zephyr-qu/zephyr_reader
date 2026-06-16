import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节与页面导航。
class ChapterNavigator {
  final ReaderRepositoryInterface _repo;
  final ReaderConfig _config;
  final ReaderPageState _pageState;
  final ChapterLoader _loader;
  final PaginationCoordinator _pagination;
  final AsyncSignal<List<Chapter>> _chapters;
  final Signal<int> _totalPages;
  final Signal<int> _pageIndex;

  ChapterNavigator(
    this._repo,
    this._config,
    this._pageState,
    this._loader,
    this._pagination,
    this._chapters,
    this._totalPages,
    this._pageIndex,
  );

  Future<void> previousChapter() async {
    if (_pageState.chapterIndex.value > 0) {
      final newChapterIndex = _pageState.chapterIndex.value - 1;
      await _loader.loadChapter(newChapterIndex, preserveContent: true);
      _pageIndex.value = (_totalPages.value - 1).clamp(0, 0x7FFFFFFF);
      final descriptors = _repo.descriptors;
      if (descriptors != null && _pageIndex.value < descriptors.length) {
        _pageState.currentCharOffset.value =
            descriptors[_pageIndex.value].endOffset;
      } else if (_repo.currentPages != null &&
          _pageIndex.value < _repo.currentPages!.length) {
        _pageState.currentCharOffset.value =
            _repo.currentPages![_pageIndex.value].endOffset;
      }
    }
  }

  Future<void> nextChapter() async {
    final chapterList = _chapters.value.value ?? [];
    if (_pageState.chapterIndex.value < chapterList.length - 1) {
      final newChapterIndex = _pageState.chapterIndex.value + 1;
      await _loader.loadChapter(newChapterIndex, preserveContent: true);
    }
  }

  Future<void> jumpToChapter(int chapterIndex) async {
    await _loader.loadChapter(chapterIndex);
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await _loader.loadChapter(
      chapterIndex,
      initialCharOffset: charOffset,
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
    if (pageIndex < 0 || pageIndex > _totalPages.value) return;
    _pageIndex.value = pageIndex;

    final descriptors = _repo.descriptors;
    if (descriptors != null && pageIndex < descriptors.length) {
      _pageState.currentCharOffset.value = descriptors[pageIndex].startOffset;
    } else {
      final pages = _repo.currentPages;
      if (pages != null && pageIndex < pages.length) {
        _pageState.currentCharOffset.value = pages[pageIndex].startOffset;
      }
    }

    _repo.ensurePageWindow(pageIndex);
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = _pageState.chapterContent.value.value?.length ?? 0;
    _pageState.currentCharOffset.value = charOffset.clamp(0, contentLength);
  }

  void consumePendingJumpOffset() {
    _pageState.pendingJumpCharOffset.value = null;
  }

  /// 预加载相邻章节的首页文本内容（当前章节 +1），用于跨章节翻页。
  Future<void> preloadAdjacentFirstPages(int centerIndex) async {
    final chapterList = _chapters.value.value ?? [];
    if (chapterList.isEmpty) return;
    if (centerIndex + 1 < chapterList.length) {
      final nextIdx = centerIndex + 1;
      await _repo.preloadNextChapterFirstPage(
        _pageState.bookId.value,
        nextIdx,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: _pagination.pageWidth,
        height: _pagination.pageHeight,
        padding: _config.padding.value,
      );
    }
  }
}
