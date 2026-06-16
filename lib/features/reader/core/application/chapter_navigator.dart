import 'dart:async';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_loader.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
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
  Future<void> previousChapter() async {
    if (_chapterVM.chapterIndex.value > 0) {
      final newChapterIndex = _chapterVM.chapterIndex.value - 1;
      await _loader.loadChapter(newChapterIndex, preserveContent: true);
      _pageIndex.value = (_totalPages.value - 1).clamp(0, 0x7FFFFFFF);
      final descriptors = _repo.descriptors;
      if (descriptors != null && _pageIndex.value < descriptors.length) {
        _chapterVM.currentCharOffset.value =
            descriptors[_pageIndex.value].endOffset;
      }
    }
  }

  Future<void> nextChapter() async {
    final chapterList = _chapters.value.value ?? [];
    if (_chapterVM.chapterIndex.value < chapterList.length - 1) {
      final newChapterIndex = _chapterVM.chapterIndex.value + 1;
      await _loader.loadChapter(newChapterIndex, preserveContent: true);
    }
  }

  Future<void> jumpToChapter(int chapterIndex) async {
    await _loader.loadChapter(chapterIndex);
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await _loader.loadChapter(chapterIndex, initialCharOffset: charOffset);
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
      _chapterVM.currentCharOffset.value = descriptors[pageIndex].startOffset;
    }

    _repo.ensurePageWindow(pageIndex);
  }

  void updateCurrentCharOffset(int charOffset) {
    final contentLength = _chapterVM.chapterContent.value.value?.length ?? 0;
    _chapterVM.currentCharOffset.value = charOffset.clamp(0, contentLength);
  }

  void consumePendingJumpOffset() {
    _chapterVM.pendingJumpCharOffset.value = null;
  }

  /// 预加载相邻章节的首页文本 + staging（descriptors + 首页 content），用于跨章节翻页。
  Future<void> preloadAdjacentFirstPages(int centerIndex) async {
    final chapterList = _chapters.value.value ?? [];
    if (chapterList.isEmpty) return;
    if (centerIndex + 1 < chapterList.length) {
      final nextIdx = centerIndex + 1;
      // 保留旧 firstSpine 预加载（scroll/pagination 模式仍需）
      await _repo.preloadNextChapterFirstPage(
        _chapterVM.bookId.value,
        nextIdx,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: _pagination.pageWidth,
        height: _pagination.pageHeight,
        padding: _config.padding.value,
      );
      unawaited(_repo.preloadNextChapterStaging(
        _chapterVM.bookId.value,
        nextIdx,
        fontSize: _config.fontSize.value,
        lineHeight: _config.lineHeight.value,
        width: _pagination.pageWidth,
        height: _pagination.pageHeight,
        padding: _config.padding.value,
        devicePixelRatio: _pagination.devicePixelRatio,
        fontFamily: _pagination.fontFamily,
      ));
    }
  }

}
