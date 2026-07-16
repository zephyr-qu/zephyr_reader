import 'package:zephyr_reader/features/reader/core/application/chapter_load_orchestrator.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/engine.dart';
import 'package:zephyr_reader/reader_engine/pagination/engine_utils.dart';
import 'package:zephyr_reader/reader_engine/pagination/packed_page.dart';

/// 章节分页意图。取代 `restartSession` 布尔，使 orchestrator 能显式选择路径。
///
/// 推导与契约：`chapter_pagination_intent_resolver.dart` · `discuss/INTENTS.md`
enum ChapterPaginationIntent {
  /// 换章 / 无 session：`_runCalibratedPartialPaginate` → beginPaginate(2000) → expand。
  normalLoad,

  /// 同章 + config 变化（设置重载）：走 in-place `repaginate_session`，不 dispose handle。
  configReload,

  /// 同章 + 同 config（仅 partial 待补全）：用 `repaginate_session(max_chars=null)` 升级。
  expandOnly,

  /// 下一章 staging 命中：adopt session from cache + pageIndex=0
  stagingPromoteForward,

  /// 上一章 staging 命中：adopt session from cache + pageIndex=last
  stagingPromoteBackward,
}

/// 首屏 partial 分页下的页码与 charOffset 推算结果。
class QuickPageResolveResult {
  const QuickPageResolveResult({
    required this.pageIndex,
    required this.charOffsetForPartial,
  });

  final int pageIndex;
  final int charOffsetForPartial;
}

/// 根据 session / staging / config 推导分页 intent。
///
/// 契约见 `discuss/INTENTS.md`；不得在此增加第 6 个 intent（须 ADR）。
ChapterPaginationIntent resolveChapterPaginationIntent({
  required int chapterIndex,
  required ChapterNavigationKind navigationKind,
  required ChapterContentRepository contentRepo,
  required PaginationEngine engine,
  required PaginationCoordinator pagination,
}) {
  if (navigationKind == ChapterNavigationKind.adjacentCrossChapter) {
    final nextStaging = contentRepo.nextChapterStaging;
    if (nextStaging != null && nextStaging.chapterIndex == chapterIndex) {
      final currentHash = pagination.computeConfigHash();
      if (nextStaging.configHash == currentHash) {
        return ChapterPaginationIntent.stagingPromoteForward;
      }
    }
    final prevStaging = contentRepo.prevChapterStaging;
    if (prevStaging != null && prevStaging.chapterIndex == chapterIndex) {
      final currentHash = pagination.computeConfigHash();
      if (prevStaging.configHash == currentHash) {
        return ChapterPaginationIntent.stagingPromoteBackward;
      }
    }
  }

  final hash = engine.session.sessionConfigHash;
  final descriptors = engine.session.descriptors;
  final sessionChapterIndex = engine.session.sessionChapterIndex;

  final sessionValid =
      hash != null &&
      (descriptors?.isNotEmpty == true) &&
      sessionChapterIndex == chapterIndex;

  if (!sessionValid) return ChapterPaginationIntent.normalLoad;

  final currentHash = pagination.computeConfigHash();
  if (currentHash != hash) return ChapterPaginationIntent.configReload;

  return ChapterPaginationIntent.expandOnly;
}

/// normalLoad 清空旧内容；其余 intent 保留当前页骨架直至新 descriptors 就绪。
bool shouldPreserveContentForIntent(ChapterPaginationIntent intent) =>
    intent != ChapterPaginationIntent.normalLoad;

/// partial descriptors 下由书签 [initialCharOffset] 推算首屏页码。
QuickPageResolveResult resolveQuickPageForPartial({
  required List<PackedPage> descriptors,
  required int initialCharOffset,
  required bool isPartial,
  required int fallbackPageIndex,
  int Function(int charOffset, List<PackedPage> descriptors)? resolvePageIndex,
}) {
  final partialEnd = descriptors.last.endOffset;
  final offsetBeyondPartial = isPartial && initialCharOffset > partialEnd;
  if (offsetBeyondPartial) {
    return QuickPageResolveResult(
      pageIndex: 0,
      charOffsetForPartial: initialCharOffset.clamp(0, partialEnd),
    );
  }

  final charOffsetForPartial = initialCharOffset.clamp(0, partialEnd);
  final resolved = resolvePageIndex != null
      ? resolvePageIndex(charOffsetForPartial, descriptors)
      : PaginationUtils.resolvePageIndexForOffset(
          descriptors,
          charOffsetForPartial,
        );
  final pageIndex = resolved >= 0 ? resolved : fallbackPageIndex;
  return QuickPageResolveResult(
    pageIndex: pageIndex,
    charOffsetForPartial: charOffsetForPartial,
  );
}
