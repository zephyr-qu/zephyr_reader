/// 章节信息
class ChapterInfo {
  /// 章节 ID
  final int chapterId;

  /// 章节标题
  final String title;

  /// 起始索引
  final int startIndex;

  /// 结束索引
  final int endIndex;

  /// 内容长度
  final int contentLength;

  /// 章节索引
  final int index;

  ChapterInfo({
    required this.chapterId,
    required this.title,
    required this.startIndex,
    required this.endIndex,
    required this.contentLength,
    required this.index,
  });
}
