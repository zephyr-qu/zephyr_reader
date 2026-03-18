import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/core/local/file_storage.dart';
import 'package:zephyr_reader/shared/utils/logging.dart';

import '../domain/reader_repository.dart';

/// 阅读器服务实现
@LazySingleton(as: ReaderRepository)
class ReaderService implements ReaderRepository {
  final AppDatabase _database;
  final FileStorage _fileStorage;

  ReaderService(this._database, this._fileStorage);

  @override
  Future<Chapter?> getChapter(int bookId, int chapterIndex) async {
    final chapter = await _database.getChapter(bookId, chapterIndex);

    if (chapter == null) {
      return null;
    }

    // 加载章节内容
    final content = await _fileStorage.readString(chapter.contentFile);
    if (content == null) {
      Logging.warning('Chapter content not found: ${chapter.contentFile}');
      return chapter;
    }

    // 这里可以创建一个包含内容的扩展类，或者直接返回内容
    // 为了简化，我们假设内容会通过其他方式传递
    return chapter;
  }

  @override
  Future<List<Chapter>> getChapters(int bookId) async {
    return await _database.getChaptersByBookId(bookId);
  }

  @override
  Future<void> saveReadingHistory(
    int bookId,
    int chapterId,
    int position,
    int duration,
  ) async {
    final now = DateTime.now();

    // 检查是否已有阅读历史
    final existing = await _database.getBookReadingHistory(bookId);

    if (existing != null) {
      // 更新现有记录
      await (_database.update(
        _database.readingHistories,
      )..where((tbl) => tbl.bookId.equals(bookId))).write(
        ReadingHistoriesCompanion(
          chapterId: Value(chapterId),
          position: Value(position),
          readTime: Value(now),
          duration: Value(existing.duration + duration),
        ),
      );
    } else {
      // 创建新记录
      await _database
          .into(_database.readingHistory)
          .insert(
            ReadingHistoryCompanion.insert(
              bookId: bookId,
              chapterId: chapterId,
              position: position,
              readTime: Value(now),
              duration: Value(duration),
            ),
          );
    }
  }

  @override
  Future<ReadingHistory?> getReadingHistory(int bookId) async {
    return await _database.getBookReadingHistory(bookId);
  }

  @override
  Future<int> addBookmark(
    int bookId,
    int chapterId,
    int position,
    String? note,
  ) async {
    return await _database
        .into(_database.bookmarks)
        .insert(
          BookmarksCompanion.insert(
            bookId: bookId,
            chapterId: chapterId,
            position: position,
            note: Value(note),
            bookmarkId: '',
            pageIndex: 0,
            title: '',
            createdTimestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<List<Bookmark>> getBookmarks(int bookId) async {
    return await _database.getBookmarks(bookId);
  }

  @override
  Future<bool> deleteBookmark(String bookmarkId) async {
    return await (_database.delete(
          _database.bookmarks,
        )..where((tbl) => tbl.bookmarkId.equals(bookmarkId))).go() >
        0;
  }

  /// 保存章节内容到文件
  Future<bool> saveChapterContent(
    int bookId,
    int chapterIndex,
    String content,
  ) async {
    final filename = 'Books/$bookId/chapter_$chapterIndex.txt';
    return await _fileStorage.saveString(filename, content);
  }

  @override
  Future<String?> getChapterContent(String contentFile) async {
    return await _fileStorage.readString(contentFile);
  }
}
