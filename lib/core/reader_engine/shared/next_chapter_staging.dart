import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';

class NextChapterStaging {
  final int chapterIndex;
  final BigInt configHash;
  /// PagePlan 原生列表（ADR-018 完成，descriptors 已删除）。
  final List<PagePlan> pagePlans;
  final String firstPageContent;
  final bool isPartial;
  final String? bookId;
  final PagePlan? anchorPagePlan;
  final LayoutSpec spec;

  const NextChapterStaging({
    required this.chapterIndex,
    required this.configHash,
    required this.pagePlans,
    required this.firstPageContent,
    required this.isPartial,
    this.bookId,
    this.anchorPagePlan,
    required this.spec,
  });

  bool matches(int chapterIndex, BigInt configHash) =>
      this.chapterIndex == chapterIndex && this.configHash == configHash;
}
