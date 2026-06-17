import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/application/scroll_document_composer.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';

/// 滚动模式章界协调器。
///
/// 管理 [ScrollDocumentComposer] 的生命周期、内容加载与信号更新。
/// 绕过 [ChapterLoadOrchestrator] 全量分页 pipeline，仅负责纯文本拼接。
class ScrollBoundaryCoordinator {
  final ReaderRepositoryInterface _repo;
  final void Function(int chapterIndex, int charOffset) _onPositionChanged;
  final void Function(int chapterIndex) _onChapterChanged;
  final void Function(List<ScrollChapterSegment> segments) _onSegmentsChanged;

  ScrollDocumentComposer? _composer;
  int _loadingGen = 0;
  bool _isLoadingNext = false;
  bool _isLoadingPrev = false;

  ScrollBoundaryCoordinator({
    required ReaderRepositoryInterface repo,
    required void Function(int chapterIndex, int charOffset) onPositionChanged,
    required void Function(int chapterIndex) onChapterChanged,
    required void Function(List<ScrollChapterSegment> segments) onSegmentsChanged,
  })  : _repo = repo,
        _onPositionChanged = onPositionChanged,
        _onChapterChanged = onChapterChanged,
        _onSegmentsChanged = onSegmentsChanged;

  ScrollDocumentComposer? get composer => _composer;

  /// 当前段列表。
  List<ScrollChapterSegment> get segments =>
      _composer?.segments ?? [];

  /// 初始化中心章节。
  void init(int chapterIndex, String content) {
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(_contentToSegment(chapterIndex, content));
    _emitSegments();
  }

  /// 滚近底时调用：若 next 段未就绪则加载。
  Future<void> appendNext({
    required String bookId,
    required ReadingMode readingMode,
  }) async {
    if (_composer == null || _isLoadingNext) return;
    final nextIdx = _composer!.centerChapterIndex + 1;
    if (_composer!.hasChapter(nextIdx)) return;

    _isLoadingNext = true;
    final gen = ++_loadingGen;
    try {
      final content = await _repo.loadChapterContent(
        bookId,
        nextIdx,
        readingMode: readingMode,
      );
      if (gen != _loadingGen || _composer == null) return;
      _composer!.appendNext(_contentToSegment(nextIdx, content));
      _emitSegments();
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
    final prevIdx = _composer!.centerChapterIndex - 1;
    if (prevIdx < 0) return;
    if (_composer!.hasChapter(prevIdx)) return;

    _isLoadingPrev = true;
    final gen = ++_loadingGen;
    try {
      final content = await _repo.loadChapterContent(
        bookId,
        prevIdx,
        readingMode: readingMode,
      );
      if (gen != _loadingGen || _composer == null) return;
      _composer!.prependPrev(_contentToSegment(prevIdx, content));
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

  /// 重置到指定章节。
  void reset(String bookId, int chapterIndex, String content) {
    _loadingGen++;
    _isLoadingNext = false;
    _isLoadingPrev = false;
    _composer = ScrollDocumentComposer(centerChapterIndex: chapterIndex);
    _composer!.reset(_contentToSegment(chapterIndex, content));
    _emitSegments();
  }

  void _emitSegments() {
    _onSegmentsChanged(_composer?.segments ?? []);
  }

  static ScrollChapterSegment _contentToSegment(
      int chapterIndex, String content) {
    final paragraphs = content
        .split('\n\n')
        .where((p) => p.trim().isNotEmpty)
        .toList();
    var acc = 0;
    final offsets = paragraphs.map((p) {
      final o = acc;
      acc += p.length + 2;
      return o;
    }).toList();
    return ScrollChapterSegment(
      chapterIndex: chapterIndex,
      paragraphs: paragraphs,
      paragraphCharOffsets: offsets,
    );
  }
}
