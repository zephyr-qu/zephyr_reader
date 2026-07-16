import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/progress.dart' as progress_api;

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

/// 阅读进度仓库。
@Injectable()
class ProgressRepository {
  ReadingProgressData? _currentProgress;

  Future<ReadingProgressData?> load(String bookId) async {
    if (_currentProgress != null && _currentProgress!.bookId == bookId) {
      return _currentProgress;
    }
    final rp = await progress_api.getProgress(bookId: bookId);
    if (rp == null) return null;
    _currentProgress = ReadingProgressData(
      bookId: bookId,
      chapterIndex: rp.chapterIndex,
      charOffset: rp.charOffset.toInt(),
      readingTimeSeconds: rp.readingTimeSeconds.toInt(),
      lastReadAt: rp.lastReadAt,
    );
    return _currentProgress;
  }
}
