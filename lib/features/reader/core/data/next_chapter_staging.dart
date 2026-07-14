import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';

class NextChapterStaging {
  final int chapterIndex;
  final BigInt configHash;
  final List<PackedPage> descriptors;
  final String firstPageContent;
  final bool isPartial;
  final ChapterPaginationMode paginationMode;
  final String? bookId;
  final List<PackedBlockSlice>? anchorPageBlocks;

  const NextChapterStaging({
    required this.chapterIndex,
    required this.configHash,
    required this.descriptors,
    required this.firstPageContent,
    required this.isPartial,
    this.paginationMode = ChapterPaginationMode.plainText,
    this.bookId,
    this.anchorPageBlocks,
  });

  bool matches(int chapterIndex, BigInt configHash) =>
      this.chapterIndex == chapterIndex && this.configHash == configHash;
}
