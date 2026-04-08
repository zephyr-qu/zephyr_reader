/// 基于 Rust 存储的阅读器仓库实现
library;

import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/features/reader/domain/repositories/reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: ReaderRepository)
class RustReaderRepository implements ReaderRepository {
  final _storage = RustStorageService();

  @override
  Future<DbChapter?> getChapter(int bookId, int chapterIndex) async {
    final chapters = await getChapters(bookId);
    return chapters.where((c) => c.chapterIndex == chapterIndex).firstOrNull;
  }

  @override
  Future<List<DbChapter>> getChapters(int bookId) async {
    return _storage
        .getChaptersByBook('book_$bookId')
        .then(
          (rustChapters) => rustChapters
              .map(
                (rc) => DbChapter(
                  id: rc.id,
                  bookId: rc.bookId,
                  title: rc.title,
                  contentFile: rc.contentFile,
                  chapterIndex: rc.chapterIndex,
                  wordCount: rc.wordCount,
                  cachedAt: rc.cachedAt,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> saveReadingHistory(
    String bookId,
    int chapterId,
    int position,
    int duration,
  ) async {
    await _storage.recordReadingSession(
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      startOffset: 0,
      endOffset: position,
      durationSeconds: duration,
      charactersRead: position,
    );
  }

  @override
  Future<DbGlobalStats?> getReadingHistory(int bookId) async {
    return _storage.getReadingStats();
  }

  @override
  Future<int> addBookmark(
    String bookId,
    int chapterId,
    int position,
  ) async {
    final rustBookmark = await _storage.createBookmark(
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      charOffset: position,
      title: '书签',
    );
    return rustBookmark.id.hashCode;
  }

  @override
  Future<List<DbBookmark>> getBookmarks(String bookId) async {
    return _storage.getBookmarks('book_$bookId');
  }

  @override
  Future<bool> deleteBookmark(int bookmarkId) async {
    try {
      await _storage.deleteBookmark('bm_$bookmarkId');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getChapterContent(String contentFile) async {
    final file = File(contentFile);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
