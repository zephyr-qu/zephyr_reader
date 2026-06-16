import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class NextChapterStaging {
  final int chapterIndex;
  final int configHash;
  final List<PageDescriptor> descriptors;
  final String firstPageContent;
  final bool isPartial;

  const NextChapterStaging({
    required this.chapterIndex,
    required this.configHash,
    required this.descriptors,
    required this.firstPageContent,
    required this.isPartial,
  });

  bool matches(int chapterIndex, int configHash) =>
      this.chapterIndex == chapterIndex && this.configHash == configHash;
}
