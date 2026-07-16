/// 阅读进度数据。
///
/// 只持久化 chapterIndex + charOffset（I1）。
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int charOffset;
  final int readingTimeSeconds;
  final DateTime lastReadAt;

  const ReadingProgressData({
    required this.bookId,
    required this.chapterIndex,
    required this.charOffset,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });
}

/// 阅读进度仓库抽象。
abstract class ProgressRepository {
  Future<ReadingProgressData?> load(String bookId);
}
