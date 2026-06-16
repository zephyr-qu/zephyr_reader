import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;

@Injectable(as: ProgressRepository)
class RustProgressRepository implements ProgressRepository {
  ReadingProgressData? _currentProgress;

  @override
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
      pageIndex: rp.pageIndex,
      totalPages: rp.totalPages,
      readingTimeSeconds: rp.readingTimeSeconds.toInt(),
      lastReadAt: rp.lastReadAt,
    );
    return _currentProgress;
  }
}
