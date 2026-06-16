import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

/// 单次章节加载请求的不可变参数。
class ChapterLoadRequest {
  final int chapterIndex;
  final int initialCharOffset;
  final ReadingMode readingMode;
  final bool? preserveContent;
  final Future<void> Function()? onChapterLoaded;

  const ChapterLoadRequest({
    required this.chapterIndex,
    this.initialCharOffset = 0,
    this.readingMode = ReadingMode.pagination,
    this.preserveContent,
    this.onChapterLoaded,
  });
}
