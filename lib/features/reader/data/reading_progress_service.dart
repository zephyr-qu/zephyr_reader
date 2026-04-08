/// 阅读进度服务（基于 Rust）
///
/// 功能：
/// - 保存和加载阅读进度
/// - 记录阅读时长
/// - 所有数据持久化到 Rust 侧的 SQLite 数据库
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/error/app_error.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';

/// 阅读进度数据
class ReadingProgressData {
  final String bookId;
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final int readingTimeSeconds;
  final DateTime lastReadAt;

  ReadingProgressData({
    required this.bookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.totalPages,
    required this.readingTimeSeconds,
    required this.lastReadAt,
  });

  double get progressPercent =>
      totalPages > 0 ? (pageIndex + 1) / totalPages : 0.0;

  String get progressText => '${(progressPercent * 100).toStringAsFixed(1)}%';

  String get readingTimeText {
    final minutes = readingTimeSeconds ~/ 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      return '$hours小时${minutes % 60}分钟';
    } else if (minutes > 0) {
      return '$minutes分钟${readingTimeSeconds % 60}秒';
    } else {
      return '$readingTimeSeconds秒';
    }
  }
}

/// 阅读进度服务
@injectable
class ReadingProgressService {
  final _storage = RustStorageService();
  ReadingProgressData? _currentProgress;

  Future<Result<void>> updateReadingProgress({
    required String bookId,
    required int chapterId,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {
    return Result.guardAsync(() async {
      await _storage.saveReadingProgress(
        bookId: bookId,
        chapterIndex: chapterId,
        charOffset: 0,
        pageIndex: pageIndex,
        totalPages: totalPages,
        readingTimeSeconds: readingTimeSeconds,
      );
      _currentProgress = ReadingProgressData(
        bookId: bookId,
        chapterIndex: chapterId,
        pageIndex: pageIndex,
        totalPages: totalPages,
        readingTimeSeconds: readingTimeSeconds,
        lastReadAt: DateTime.now(),
      );
    });
  }

  Future<Result<ReadingProgressData?>> loadReadingProgress(String bookId) async {
    return Result.guardAsync(() async {
      if (_currentProgress != null && _currentProgress!.bookId == bookId) {
        return _currentProgress;
      }
      final progress = await _storage.getReadingProgress(bookId);
      if (progress == null) return null;
      _currentProgress = ReadingProgressData(
        bookId: bookId,
        chapterIndex: progress.chapterIndex,
        pageIndex: progress.pageIndex,
        totalPages: progress.totalPages,
        readingTimeSeconds: progress.readingTimeSeconds.toInt(),
        lastReadAt: progress.lastReadAt,
      );
      return _currentProgress;
    });
  }

  ReadingProgressData? get currentProgress => _currentProgress;

  Future<Result<void>> clearReadingProgress(String bookId) async {
    return Result.guardAsync(() async {
      await _storage.clearReadingProgress(bookId);
      if (_currentProgress?.bookId == bookId) {
        _currentProgress = null;
      }
    });
  }

  Future<Result<List<ReadingProgressData>>> getAllReadingProgress() async {
    return Result.guardAsync(() async {
      final books = await _storage.getAllBooks();
      final result = <ReadingProgressData>[];
      for (final book in books) {
        final progress = await _storage.getReadingProgress(book.bookId);
        if (progress != null) {
          result.add(
            ReadingProgressData(
              bookId: book.bookId,
              chapterIndex: progress.chapterIndex,
              pageIndex: progress.pageIndex,
              totalPages: progress.totalPages,
              readingTimeSeconds: progress.readingTimeSeconds.toInt(),
              lastReadAt: progress.lastReadAt,
            ),
          );
        }
      }
      return result;
    });
  }

  void clearCache() {
    _currentProgress = null;
  }
}
