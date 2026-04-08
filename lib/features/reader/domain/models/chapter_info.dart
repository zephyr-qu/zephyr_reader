/// 章节信息
///
/// 对应 Rust 端的 `ChapterInfo`（解析器输出），用于书籍导入和解析阶段。
/// 注意：`chapterId` 为字符串类型（UUID），与数据库模型 `DbChapter.id` 一致。
class ChapterInfo {
  /// 章节唯一标识 (UUID)
  final String chapterId;

  /// 章节标题
  final String title;

  /// 起始字符偏移量
  final int startIndex;

  /// 结束字符偏移量
  final int endIndex;

  /// 内容长度（字符数）
  final int contentLength;

  /// 章节序号（顺序索引，从 0 开始）
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
