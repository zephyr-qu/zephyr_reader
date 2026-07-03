import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

class NextChapterStaging {
  final int chapterIndex;
  final BigInt configHash;
  final List<PageDescriptor> descriptors;
  final String firstPageContent;
  final bool isPartial;
  final ChapterPaginationMode paginationMode;
  final String? filePath;
  final List<PageBlockSlice>? anchorPageBlocks;

  const NextChapterStaging({
    required this.chapterIndex,
    required this.configHash,
    required this.descriptors,
    required this.firstPageContent,
    required this.isPartial,
    this.paginationMode = ChapterPaginationMode.plainText,
    this.filePath,
    this.anchorPageBlocks,
  });

  bool matches(int chapterIndex, BigInt configHash) =>
      this.chapterIndex == chapterIndex && this.configHash == configHash;
}
