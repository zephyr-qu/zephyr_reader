import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';

/// 单次章节加载请求的不可变参数。
class ChapterLoadRequest {
  final int chapterIndex;
  final int initialCharOffset;
  final ChapterPaginationIntent intent;
  final bool preserveContent;
  final Future<void> Function()? onChapterLoaded;

  const ChapterLoadRequest({
    required this.chapterIndex,
    this.initialCharOffset = 0,
    this.intent = ChapterPaginationIntent.normalLoad,
    this.preserveContent = false,
    this.onChapterLoaded,
  });
}
