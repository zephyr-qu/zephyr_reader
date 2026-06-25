import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_layout_params.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/features/reader/core/application/scroll_document_composer.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_notice.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 滚动模式章界协调器。
///
/// 管理 [ScrollDocumentComposer] 的生命周期、内容加载与信号更新。
/// Scroll 主路径走 IR（ADR-009）；双语仍可用 rich + epubRichSkipped 降级。
class ScrollBoundaryCoordinator {
  final ReaderRepositoryInterface _repo;
  final void Function(int chapterIndex, int charOffset) _onPositionChanged;
  final void Function(int chapterIndex) _onChapterChanged;
  final void Function(List<ScrollChapterSegment> segments) _onSegmentsChanged;
  final void Function(ReaderNotice notice)? _onReaderNotice;

  ScrollDocumentComposer? _composer;
  int _loadingGen = 0;
  bool _isLoadingNext = false;
  bool _isLoadingPrev = false;

  ScrollBoundaryCoordinator({
    required ReaderRepositoryInterface repo,
    required void Function(int chapterIndex, int charOffset) onPositionChanged,
    required void Function(int chapterIndex) onChapterChanged,
    required void Function(List<ScrollChapterSegment> segments) onSegmentsChanged,
    void Function(ReaderNotice notice)? onReaderNotice,
  })  : _repo = repo,
        _onPositionChanged = onPositionChanged,
        _onChapterChanged = onChapterChanged,
        _onSegmentsChanged = onSegmentsChanged,
        _onReaderNotice = onReaderNotice;

  ScrollDocumentComposer? get composer => _composer;

  /// 当前段列表。
  List<ScrollChapterSegment> get segments =>
      _composer?.segments ?? [];

  /// 初始化中心章节。
  void init(
    int chapterIndex,
    String content, {
    List<RichParagraph>? richParagraphs,
    TextSpan? richRootSpan,
    ChapterContentIr? chapterIr,
    String? chapterFilePath,
  }) {
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(
      ScrollSegmentFactory.fromPayload(
        chapterIndex,
        (
          content: content,
          richParagraphs: richParagraphs,
          richRootSpan: richRootSpan,
          epubRichSkipped: false,
          chapterIr: chapterIr,
          chapterFilePath: chapterFilePath,
        ),
      ),
    );
    _emitSegments();
  }

  /// 滚近底时调用：若 next 段未就绪则加载。
  Future<void> appendNext({
    required String bookId,
    required ReadingMode readingMode,
  }) async {
    if (_composer == null || _isLoadingNext) return;
    final segments = _composer!.segments;
    final nextIdx = segments.isEmpty
        ? _composer!.centerChapterIndex + 1
        : segments.last.chapterIndex + 1;
    if (_composer!.hasChapter(nextIdx)) return;

    _isLoadingNext = true;
    final gen = ++_loadingGen;
    try {
      final payload = await _repo.loadScrollSegment(
        bookId,
        nextIdx,
        readingMode: readingMode,
      );
      if (gen != _loadingGen || _composer == null) return;
      _composer!.appendNext(ScrollSegmentFactory.fromPayload(nextIdx, payload));
      _emitSegments();
      if (payload.epubRichSkipped &&
          readingMode == ReadingMode.bilingual) {
        _onReaderNotice?.call(ReaderNotice.epubRichSkipped);
      }
      unawaited(
        _repo.preloadChapter(bookId, nextIdx + 1).catchError((_) {}),
      );
    } catch (e) {
      Logging.debug('[ScrollCoord] appendNext failed: $e');
    } finally {
      _isLoadingNext = false;
    }
  }

  /// 滚近顶时调用：若 prev 段未就绪则加载。
  Future<void> prependPrev({
    required String bookId,
    required ReadingMode readingMode,
  }) async {
    if (_composer == null || _isLoadingPrev) return;
    final segments = _composer!.segments;
    final prevIdx = segments.isEmpty
        ? _composer!.centerChapterIndex - 1
        : segments.first.chapterIndex - 1;
    if (prevIdx < 0) return;
    if (_composer!.hasChapter(prevIdx)) return;

    _isLoadingPrev = true;
    final gen = ++_loadingGen;
    try {
      final payload = await _repo.loadScrollSegment(
        bookId,
        prevIdx,
        readingMode: readingMode,
      );
      if (gen != _loadingGen || _composer == null) return;
      _composer!.prependPrev(
        ScrollSegmentFactory.fromPayload(prevIdx, payload),
      );
      _emitSegments();
      if (payload.epubRichSkipped &&
          readingMode == ReadingMode.bilingual) {
        _onReaderNotice?.call(ReaderNotice.epubRichSkipped);
      }
    } catch (e) {
      Logging.debug('[ScrollCoord] prependPrev failed: $e');
    } finally {
      _isLoadingPrev = false;
    }
  }

  /// 用户滚动进入新的章界时调用。
  void onSegmentChanged(int chapterIndex, {int charOffset = 0}) {
    _composer?.updateCenterChapter(chapterIndex);
    _onChapterChanged(chapterIndex);
    _onPositionChanged(chapterIndex, charOffset);
    _emitSegments();
  }

  /// 根据滚动偏移映射进度；跨章时自动 [onSegmentChanged]。
  void reportScrollPosition(
    double scrollOffset,
    ScrollLayoutParams layout,
  ) {
    if (_composer == null) return;
    final pos = _composer!.charOffsetAtOffset(scrollOffset, layout);
    if (pos.chapterIndex != _composer!.centerChapterIndex) {
      onSegmentChanged(pos.chapterIndex, charOffset: pos.charOffset);
    } else {
      _onPositionChanged(pos.chapterIndex, pos.charOffset);
    }
  }

  /// 重置到指定章节。
  void reset(
    String bookId,
    int chapterIndex,
    String content, {
    List<RichParagraph>? richParagraphs,
    TextSpan? richRootSpan,
    ChapterContentIr? chapterIr,
    String? chapterFilePath,
  }) {
    _loadingGen++;
    _isLoadingNext = false;
    _isLoadingPrev = false;
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(
      ScrollSegmentFactory.fromPayload(
        chapterIndex,
        (
          content: content,
          richParagraphs: richParagraphs,
          richRootSpan: richRootSpan,
          epubRichSkipped: false,
          chapterIr: chapterIr,
          chapterFilePath: chapterFilePath,
        ),
      ),
    );
    _emitSegments();
  }

  void _emitSegments() {
    _onSegmentsChanged(_composer?.segments ?? []);
  }
}
