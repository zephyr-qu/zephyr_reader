import 'dart:async';

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_chapter_segment.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_layout_params.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_segment_factory.dart';
import 'package:zephyr_reader/core/reader_engine/scroll/scroll_document_composer.dart';
import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 滚动模式章界协调器。
///
/// 管理 [ScrollDocumentComposer] 的生命周期、内容加载与信号更新。
/// Scroll 主路径走 IR（ADR-009）。
class ScrollBoundaryCoordinator {
  final ChapterContentRepository _contentRepo;
  final void Function(int chapterIndex, int charOffset) _onPositionChanged;
  final void Function(int chapterIndex) _onChapterChanged;
  final void Function(List<ScrollChapterSegment> segments) _onSegmentsChanged;

  ScrollDocumentComposer? _composer;
  int _appendLoadingGen = 0;
  int _prependLoadingGen = 0;
  bool _isLoadingNext = false;
  bool _isLoadingPrev = false;

  ScrollBoundaryCoordinator({
    required this._contentRepo,
    required this._onPositionChanged,
    required this._onChapterChanged,
    required this._onSegmentsChanged,
  });

  ScrollDocumentComposer? get composer => _composer;

  /// 当前段列表。
  List<ScrollChapterSegment> get segments => _composer?.segments ?? [];

  /// 初始化中心章节。
  void init(
    int chapterIndex,
    String content, {
    ReaderChapterIr? chapterIr,
    String? chapterFilePath,
  }) {
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(
      ScrollSegmentFactory.fromPayload(chapterIndex, (
        content: content,

        chapterIr: chapterIr,
        chapterFilePath: chapterFilePath,
      )),
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
    final gen = ++_appendLoadingGen;
    try {
      final payload = await _contentRepo.loadScrollSegment(
        bookId,
        nextIdx,
        readingMode: readingMode,
      );
      if (gen != _appendLoadingGen || _composer == null) return;
      _composer!.appendNext(ScrollSegmentFactory.fromPayload(nextIdx, payload));
      _emitSegments();
      unawaited(
        _contentRepo.preload(bookId, nextIdx + 1).catchError((Object e) {
          Logging.debug('[ScrollCoord] preloadChapter(nextIdx+1) failed: $e');
        }),
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
    final gen = ++_prependLoadingGen;
    try {
      final payload = await _contentRepo.loadScrollSegment(
        bookId,
        prevIdx,
        readingMode: readingMode,
      );
      if (gen != _prependLoadingGen || _composer == null) return;
      _composer!.prependPrev(
        ScrollSegmentFactory.fromPayload(prevIdx, payload),
      );
      _emitSegments();
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
  void reportScrollPosition(double scrollOffset, ScrollLayoutParams layout) {
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
    ReaderChapterIr? chapterIr,
    String? chapterFilePath,
  }) {
    _appendLoadingGen++;
    _prependLoadingGen++;
    _isLoadingNext = false;
    _isLoadingPrev = false;
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(
      ScrollSegmentFactory.fromPayload(chapterIndex, (
        content: content,

        chapterIr: chapterIr,
        chapterFilePath: chapterFilePath,
      )),
    );
    _emitSegments();
  }

  void _emitSegments() {
    _onSegmentsChanged(_composer?.segments ?? []);
  }
}
