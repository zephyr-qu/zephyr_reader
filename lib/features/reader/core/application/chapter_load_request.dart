/// 单次章节加载请求的不可变参数。
class ChapterLoadRequest {
  final int chapterIndex;
  final int initialCharOffset;
  final bool restartSession;
  final bool preserveContent;
  final Future<void> Function()? onChapterLoaded;

  const ChapterLoadRequest({
    required this.chapterIndex,
    this.initialCharOffset = 0,
    this.restartSession = true,
    this.preserveContent = false,
    this.onChapterLoaded,
  });
}
