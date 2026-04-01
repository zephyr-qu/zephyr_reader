
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
