/// 阅读器数据模型
library;

/// 书籍信息
class BookInfo {
  /// 书籍 ID
  final String bookId;

  /// 书籍标题
  final String title;

  /// 作者
  final String author;

  /// 章节数量
  final int chapterCount;

  /// 总字符数
  final int totalCharacters;

  /// 文件路径
  final String filePath;

  /// 文件类型
  final String fileType;

  /// 封面路径
  final String? coverPath;

  BookInfo({
    required this.bookId,
    required this.title,
    required this.author,
    required this.chapterCount,
    required this.totalCharacters,
    required this.filePath,
    required this.fileType,
    this.coverPath,
  });
}

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
