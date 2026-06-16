/// 阅读进度数据。
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;

  const ReadingProgressData({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.pageIndex,
    required this.totalPages,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });
}

/// 阅读进度仓库抽象。
abstract class ProgressRepository {
  Future<ReadingProgressData?> load(String bookId);
}
